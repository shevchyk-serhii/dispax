package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{ClientCompanyRepository, PersonRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

class LocalInMemoryClientCompanyRepo extends ClientCompanyRepository:
  private val store                                                   = new ConcurrentHashMap[ClientCompanyId, ClientCompany]()
  def create(c: ClientCompany): Task[ClientCompany]                   = ZIO.succeed { store.put(c.id, c); c }
  def findById(id: ClientCompanyId): Task[Option[ClientCompany]]      = ZIO.succeed(Option(store.get(id)))

  def findByTaxiCompany(taxiId: CompanyId): Task[List[ClientCompany]] = ZIO.succeed(
    store.values.asScala.filter(_.taxiCompanyId == taxiId).toList.sortBy(_.name)
  )
  def update(c: ClientCompany): Task[ClientCompany]                   = ZIO.succeed { store.put(c.id, c); c }
  def delete(id: ClientCompanyId): Task[Boolean]                      = ZIO.succeed(Option(store.remove(id)).isDefined)

class LocalInMemoryPersonRepo extends PersonRepository:
  private val store                                                                    = new ConcurrentHashMap[PersonId, Person]()
  def create(p: Person): Task[Person]                                                  = ZIO.succeed { store.put(p.id, p); p }
  def findById(id: PersonId): Task[Option[Person]]                                     = ZIO.succeed(Option(store.get(id)))
  def findByEmail(email: String): Task[Option[Person]]                                 = ZIO.succeed(store.values.asScala.find(_.email == email))
  def findByRole(role: PersonRole): Task[List[Person]]                                 = ZIO.succeed(store.values.asScala.filter(_.role == role).toList)

  def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = ZIO.succeed(
    store.values.asScala.filter(p => p.role == role && p.companyId.contains(companyId)).toList
  )

  def findByCompanyId(companyId: CompanyId): Task[List[Person]]                        = ZIO.succeed(
    store.values.asScala.filter(_.companyId.contains(companyId)).toList
  )
  def findAll(): Task[List[Person]]                                                    = ZIO.succeed(store.values.asScala.toList)
  def update(p: Person): Task[Person]                                                  = ZIO.succeed { store.put(p.id, p); p }
  def delete(id: PersonId): Task[Unit]                                                 = ZIO.succeed { store.remove(id); () }

  def findByStatus(status: UserStatus): Task[List[Person]]                             = ZIO.succeed(
    store.values.asScala.filter(_.status == status).toList
  )
  def searchByQuery(query: String): Task[List[Person]]                                 = ZIO.succeed(Nil)
  def updateLastLogin(id: PersonId): Task[Unit]                                        = ZIO.unit

  def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]        = ZIO.succeed(
    store.values.asScala.filter(_.clientCompanyId.contains(clientCompanyId)).toList
  )

object ClientCompanyRoutesSpec extends ZIOSpecDefault {

  private val taxiCompanyId  = UUID.fromString("00000000-0000-0000-0000-000000000010")
  private val otherCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000099")
  private val dispatcherId   = UUID.fromString("00000000-0000-0000-0000-000000000001")
  private val secretaryId    = UUID.fromString("00000000-0000-0000-0000-000000000002")
  private val clientId       = UUID.fromString("00000000-0000-0000-0000-000000000003")

  private val testJwtLayer: ZLayer[Any, Nothing, JwtService] =
    ZLayer.succeed(
      JwtConfig(
        secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
        issuer = "test-issuer",
        audience = "test-audience",
        expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
      )
    ) >>> JwtService.live

  private def generateToken(
      userId: UUID,
      role: PersonRole = PersonRole.Dispatcher,
      companyId: Option[UUID] = Some(taxiCompanyId),
      clientCompanyId: Option[UUID] = None
  ): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(
      Person(
        id = PersonId(userId),
        email = s"$userId@test.com",
        name = "Test User",
        role = role,
        passwordHash = "hash",
        companyId = companyId.map(CompanyId.apply),
        clientCompanyId = clientCompanyId.map(ClientCompanyId.apply),
        status = UserStatus.ACTIVE
      )
    )
  )

  private def runRequest(
      req: Request
  ): ZIO[ClientCompanyRepository & PersonRepository & JwtService, Nothing, Response] =
    ClientCompanyRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private def makeCompany(taxiId: UUID = taxiCompanyId, name: String = "Acme Corp"): ClientCompany = ClientCompany(
    id = ClientCompanyId.generate(),
    name = name,
    taxiCompanyId = CompanyId(taxiId)
  )

  private val layers =
    ZLayer.succeed(new LocalInMemoryClientCompanyRepo) ++
      ZLayer.succeed(new LocalInMemoryPersonRepo) ++
      testJwtLayer

  def spec =
    suite("ClientCompanyRoutes")(
      suite("GET /api/client-companies")(
        test("dispatcher gets list for own taxi company") {
          for {
            repo    <- ZIO.service[ClientCompanyRepository]
            _       <- repo.create(makeCompany())
            _       <- repo.create(makeCompany(taxiId = otherCompanyId, name = "Other Corp"))
            token   <- generateToken(dispatcherId)
            request  = Request
                         .get(URL.decode("/api/client-companies").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
            list    <- ZIO.fromEither(bodyStr.fromJson[List[ClientCompany]]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(resp.status == Status.Ok, list.length == 1, list.head.name == "Acme Corp")
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(Request.get(URL.decode("/api/client-companies").toOption.get))
          } yield assertTrue(resp.status == Status.Unauthorized)
        },
        test("returns 403 for client role") {
          for {
            token <- generateToken(clientId, role = PersonRole.Client)
            resp  <- runRequest(
                       Request
                         .get(URL.decode("/api/client-companies").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
                     )
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("POST /api/client-companies")(
        test("dispatcher creates company successfully") {
          for {
            token   <- generateToken(dispatcherId)
            body     = """{"name":"New Corp","email":"corp@test.com"}"""
            request  = Request
                         .post(URL.decode("/api/client-companies").toOption.get, Body.fromString(body))
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
            company <- ZIO.fromEither(bodyStr.fromJson[ClientCompany]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Created,
            company.name == "New Corp",
            company.email.contains("corp@test.com"),
            company.taxiCompanyId == CompanyId(taxiCompanyId)
          )
        },
        test("secretary cannot create company") {
          for {
            token  <- generateToken(secretaryId, role = PersonRole.Secretary)
            body    = """{"name":"Forbidden Corp"}"""
            request = Request
                        .post(URL.decode("/api/client-companies").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("returns 400 when user has no company") {
          for {
            token  <- generateToken(dispatcherId, companyId = None)
            body    = """{"name":"No Company Corp"}"""
            request = Request
                        .post(URL.decode("/api/client-companies").toOption.get, Body.fromString(body))
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.BadRequest)
        }
      ),
      suite("GET /api/client-companies/:id")(
        test("returns company belonging to same taxi company") {
          for {
            repo    <- ZIO.service[ClientCompanyRepository]
            company <- repo.create(makeCompany())
            token   <- generateToken(dispatcherId)
            request  = Request
                         .get(URL.decode(s"/api/client-companies/${company.id.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
            result  <- ZIO.fromEither(bodyStr.fromJson[ClientCompany]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(resp.status == Status.Ok, result.id == company.id)
        },
        test("returns 403 for company belonging to different taxi company") {
          for {
            repo    <- ZIO.service[ClientCompanyRepository]
            company <- repo.create(makeCompany(taxiId = otherCompanyId))
            token   <- generateToken(dispatcherId)
            request  = Request
                         .get(URL.decode(s"/api/client-companies/${company.id.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("returns 500 for unknown id") {
          for {
            token  <- generateToken(dispatcherId)
            request = Request
                        .get(URL.decode(s"/api/client-companies/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- runRequest(request)
          } yield assertTrue(resp.status == Status.InternalServerError)
        }
      ),
      suite("PUT /api/client-companies/:id")(
        test("updates company name") {
          for {
            repo    <- ZIO.service[ClientCompanyRepository]
            company <- repo.create(makeCompany())
            token   <- generateToken(dispatcherId)
            body     = """{"name":"Updated Corp"}"""
            request  = Request
                         .put(
                           URL.decode(s"/api/client-companies/${company.id.value}").toOption.get,
                           Body.fromString(body)
                         )
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
            result  <- ZIO.fromEither(bodyStr.fromJson[ClientCompany]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(resp.status == Status.Ok, result.name == "Updated Corp")
        },
        test("returns 403 for company of different taxi company") {
          for {
            repo    <- ZIO.service[ClientCompanyRepository]
            company <- repo.create(makeCompany(taxiId = otherCompanyId))
            token   <- generateToken(dispatcherId)
            body     = """{"name":"Hacked"}"""
            request  = Request
                         .put(
                           URL.decode(s"/api/client-companies/${company.id.value}").toOption.get,
                           Body.fromString(body)
                         )
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("DELETE /api/client-companies/:id")(
        test("deletes company with no members") {
          for {
            repo    <- ZIO.service[ClientCompanyRepository]
            company <- repo.create(makeCompany())
            token   <- generateToken(dispatcherId)
            request  = Request
                         .delete(URL.decode(s"/api/client-companies/${company.id.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            gone    <- repo.findById(company.id)
          } yield assertTrue(resp.status == Status.NoContent, gone.isEmpty)
        },
        test("returns 409 when company has members") {
          for {
            repo       <- ZIO.service[ClientCompanyRepository]
            personRepo <- ZIO.service[PersonRepository]
            company    <- repo.create(makeCompany())
            _          <- personRepo.create(
                            Person(
                              id = PersonId.generate(),
                              email = "member@test.com",
                              name = "Member",
                              role = PersonRole.Client,
                              passwordHash = "hash",
                              companyId = Some(CompanyId(taxiCompanyId)),
                              clientCompanyId = Some(company.id),
                              status = UserStatus.ACTIVE
                            )
                          )
            token      <- generateToken(dispatcherId)
            request     = Request
                            .delete(URL.decode(s"/api/client-companies/${company.id.value}").toOption.get)
                            .addHeader(Header.Authorization.Bearer(token))
            resp       <- runRequest(request)
            bodyStr    <- resp.body.asString.orDie
          } yield assertTrue(resp.status == Status.Conflict, bodyStr.contains("active members"))
        },
        test("returns 403 for company of different taxi company") {
          for {
            repo    <- ZIO.service[ClientCompanyRepository]
            company <- repo.create(makeCompany(taxiId = otherCompanyId))
            token   <- generateToken(dispatcherId)
            request  = Request
                         .delete(URL.decode(s"/api/client-companies/${company.id.value}").toOption.get)
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),
      suite("GET /api/client-companies/:id/members")(
        test("returns members of client company") {
          for {
            repo       <- ZIO.service[ClientCompanyRepository]
            personRepo <- ZIO.service[PersonRepository]
            company    <- repo.create(makeCompany())
            _          <- personRepo.create(
                            Person(
                              id = PersonId.generate(),
                              email = "emp1@corp.com",
                              name = "Employee One",
                              role = PersonRole.Client,
                              passwordHash = "hash",
                              companyId = Some(CompanyId(taxiCompanyId)),
                              clientCompanyId = Some(company.id),
                              status = UserStatus.ACTIVE
                            )
                          )
            _          <- personRepo.create(
                            Person(
                              id = PersonId.generate(),
                              email = "other@test.com",
                              name = "Other Person",
                              role = PersonRole.Client,
                              passwordHash = "hash",
                              companyId = Some(CompanyId(taxiCompanyId)),
                              status = UserStatus.ACTIVE
                            )
                          )
            token      <- generateToken(dispatcherId)
            request     = Request
                            .get(URL.decode(s"/api/client-companies/${company.id.value}/members").toOption.get)
                            .addHeader(Header.Authorization.Bearer(token))
            resp       <- runRequest(request)
            bodyStr    <- resp.body.asString.orDie
            members    <- ZIO.fromEither(bodyStr.fromJson[List[PersonDto]]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Ok,
            members.length == 1,
            members.head.email == "emp1@corp.com"
          )
        }
      )
    ).provide(layers) @@ TestAspect.sequential
}
