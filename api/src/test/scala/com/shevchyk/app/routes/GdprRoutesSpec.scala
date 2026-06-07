package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{GdprRepository, InMemoryGdprRepository, PersonRepository}
import com.shevchyk.ride.domain.{Ride, RideStatus}
import com.shevchyk.ride.repository.{RideRepository, ExpenseRepository, InMemoryExpenseRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

class StubRideRepository extends RideRepository:
  def create(ride: Ride): Task[Ride]                                                                 = ZIO.succeed(ride)
  def findById(id: RideId): Task[Option[Ride]]                                                       = ZIO.succeed(None)
  def findByStatus(status: RideStatus): Task[List[Ride]]                                             = ZIO.succeed(Nil)
  def findAll(): Task[List[Ride]]                                                                    = ZIO.succeed(Nil)
  def findByClientId(clientId: PersonId): Task[List[Ride]]                                           = ZIO.succeed(Nil)
  def findByDriverId(driverId: PersonId): Task[List[Ride]]                                           = ZIO.succeed(Nil)
  def findByCompanyId(companyId: CompanyId): Task[List[Ride]]                                        = ZIO.succeed(Nil)
  def update(ride: Ride): Task[Ride]                                                                 = ZIO.succeed(ride)
  def delete(id: RideId): Task[Unit]                                                                 = ZIO.unit
  def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]]                    = ZIO.succeed(Map.empty)
  def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                                    = ZIO.succeed(BigDecimal(0))
  def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                               = ZIO.succeed(BigDecimal(0))
  def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double]                              = ZIO.succeed(0.0)
  def countDailyStatsByCompany(companyId: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]] = ZIO.succeed(Nil)

  def earningsByDriver(
      driverId: PersonId,
      companyId: CompanyId,
      from: java.time.Instant,
      to: java.time.Instant
  ): Task[com.shevchyk.ride.domain.DriverEarnings] = ZIO.succeed(
    com.shevchyk.ride.domain.DriverEarnings(BigDecimal(0), 0, 0)
  )

  def earningsBucketsByDriver(
      driverId: PersonId,
      companyId: CompanyId,
      from: java.time.Instant,
      to: java.time.Instant,
      bucket: com.shevchyk.ride.repository.TimeBucket
  ): Task[List[(java.time.Instant, BigDecimal)]] = ZIO.succeed(Nil)
  def findAssignedRidesInWindow(from: java.time.Instant, to: java.time.Instant): Task[List[Ride]]    = ZIO.succeed(Nil)
  def clearReminders(rideId: RideId): Task[Unit]                                                     = ZIO.unit

class StubPersonRepository extends PersonRepository:
  private val store                                                                    = new ConcurrentHashMap[PersonId, Person]()
  def create(p: Person): Task[Person]                                                  = ZIO.succeed { store.put(p.id, p); p }
  def findById(id: PersonId): Task[Option[Person]]                                     = ZIO.succeed(Option(store.get(id)))
  def findByEmail(email: String): Task[Option[Person]]                                 = ZIO.succeed(store.values.asScala.find(_.email == email))
  def findByRole(role: PersonRole): Task[List[Person]]                                 = ZIO.succeed(store.values.asScala.filter(_.role == role).toList)
  def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = ZIO.succeed(Nil)
  def findByCompanyId(companyId: CompanyId): Task[List[Person]]                        = ZIO.succeed(Nil)
  def findAll(): Task[List[Person]]                                                    = ZIO.succeed(store.values.asScala.toList)
  def update(p: Person): Task[Person]                                                  = ZIO.succeed { store.put(p.id, p); p }
  def delete(id: PersonId): Task[Unit]                                                 = ZIO.succeed { store.remove(id); () }
  def findByStatus(status: UserStatus): Task[List[Person]]                             = ZIO.succeed(Nil)
  def searchByQuery(query: String): Task[List[Person]]                                 = ZIO.succeed(Nil)
  def updateLastLogin(id: PersonId): Task[Unit]                                        = ZIO.unit
  def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]        = ZIO.succeed(Nil)

object GdprRoutesSpec extends ZIOSpecDefault {

  private val taxiCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000010")
  private val userId        = UUID.fromString("00000000-0000-0000-0000-000000000001")

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
      id: UUID = userId,
      role: PersonRole = PersonRole.Client
  ): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(
      Person(
        id = PersonId(id),
        email = s"$id@test.com",
        name = "Test User",
        role = role,
        passwordHash = "hash",
        companyId = Some(CompanyId(taxiCompanyId)),
        status = UserStatus.ACTIVE
      )
    )
  )

  private def runRequest(
      req: Request
  ): ZIO[GdprRepository & PersonRepository & RideRepository & ExpenseRepository & JwtService, Nothing, Response] =
    GdprRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private val layers =
    ZLayer.succeed(InMemoryGdprRepository()) ++
      ZLayer.succeed(new StubPersonRepository) ++
      ZLayer.succeed(new StubRideRepository) ++
      ZLayer.succeed(new InMemoryExpenseRepository) ++
      testJwtLayer

  def spec =
    suite("GdprRoutes")(
      suite("GET /api/gdpr/consents")(
        test("returns empty list when no consents") {
          for {
            token    <- generateToken()
            resp     <- runRequest(
                          Request
                            .get(URL.decode("/api/gdpr/consents").toOption.get)
                            .addHeader(Header.Authorization.Bearer(token))
                        )
            bodyStr  <- resp.body.asString.orDie
            consents <- ZIO.fromEither(bodyStr.fromJson[List[GdprConsent]]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(resp.status == Status.Ok, consents.isEmpty)
        },
        test("returns user's consents") {
          for {
            repo     <- ZIO.service[GdprRepository]
            _        <- repo.createConsent(
                          GdprConsent(
                            id = GdprConsentId.generate(),
                            userId = PersonId(userId),
                            consentType = ConsentType.DataProcessing,
                            grantedAt = Instant.now()
                          )
                        )
            token    <- generateToken()
            resp     <- runRequest(
                          Request
                            .get(URL.decode("/api/gdpr/consents").toOption.get)
                            .addHeader(Header.Authorization.Bearer(token))
                        )
            bodyStr  <- resp.body.asString.orDie
            consents <- ZIO.fromEither(bodyStr.fromJson[List[GdprConsent]]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(resp.status == Status.Ok, consents.length == 1)
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(Request.get(URL.decode("/api/gdpr/consents").toOption.get))
          } yield assertTrue(resp.status == Status.Unauthorized)
        }
      ),
      suite("PUT /api/gdpr/consents")(
        test("grants a consent") {
          for {
            token   <- generateToken()
            body     = """{"consentType":"DataProcessing","granted":true}"""
            request  = Request
                         .put(URL.decode("/api/gdpr/consents").toOption.get, Body.fromString(body))
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
            consent <- ZIO.fromEither(bodyStr.fromJson[GdprConsent]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Ok,
            consent.consentType == ConsentType.DataProcessing,
            consent.revokedAt.isEmpty
          )
        },
        test("revokes an existing consent") {
          for {
            repo    <- ZIO.service[GdprRepository]
            _       <- repo.createConsent(
                         GdprConsent(
                           id = GdprConsentId.generate(),
                           userId = PersonId(userId),
                           consentType = ConsentType.Marketing,
                           grantedAt = Instant.now()
                         )
                       )
            token   <- generateToken()
            body     = """{"consentType":"Marketing","granted":false}"""
            request  = Request
                         .put(URL.decode("/api/gdpr/consents").toOption.get, Body.fromString(body))
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- runRequest(request)
            bodyStr <- resp.body.asString.orDie
          } yield assertTrue(resp.status == Status.Ok, bodyStr.contains("success"))
        },
        test("returns 401 without token") {
          for {
            resp <- runRequest(
                      Request.put(
                        URL.decode("/api/gdpr/consents").toOption.get,
                        Body.fromString("""{"consentType":"DataProcessing","granted":true}""")
                      )
                    )
          } yield assertTrue(resp.status == Status.Unauthorized)
        }
      ),
      suite("GET /api/gdpr/export")(
        test("returns data export for user") {
          for {
            token      <- generateToken()
            resp       <- runRequest(
                            Request
                              .get(URL.decode("/api/gdpr/export").toOption.get)
                              .addHeader(Header.Authorization.Bearer(token))
                          )
            bodyStr    <- resp.body.asString.orDie
            dataExport <- ZIO.fromEither(bodyStr.fromJson[GdprDataExport]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Ok,
            dataExport.user.get("id").contains(userId.toString)
          )
        }
      ),
      suite("POST /api/gdpr/deletion-request")(
        test("creates deletion request") {
          for {
            token   <- generateToken()
            resp    <- runRequest(
                         Request
                           .post(URL.decode("/api/gdpr/deletion-request").toOption.get, Body.empty)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
            bodyStr <- resp.body.asString.orDie
            req     <- ZIO.fromEither(bodyStr.fromJson[GdprRequest]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(
            resp.status == Status.Created,
            req.requestType == GdprRequestType.DELETION,
            req.userId == PersonId(userId)
          )
        }
      ),
      suite("GET /api/gdpr/requests")(
        test("returns user's GDPR requests") {
          for {
            repo     <- ZIO.service[GdprRepository]
            _        <- repo.createRequest(
                          GdprRequest(
                            id = GdprRequestId.generate(),
                            userId = PersonId(userId),
                            requestType = GdprRequestType.EXPORT,
                            requestedAt = Instant.now()
                          )
                        )
            // Endpoint requires ADMIN/DISPATCHER role.
            token    <- generateToken(role = PersonRole.Dispatcher)
            resp     <- runRequest(
                          Request
                            .get(URL.decode("/api/gdpr/requests").toOption.get)
                            .addHeader(Header.Authorization.Bearer(token))
                        )
            bodyStr  <- resp.body.asString.orDie
            requests <- ZIO.fromEither(bodyStr.fromJson[List[GdprRequest]]).mapError(new RuntimeException(_)).orDie
          } yield assertTrue(resp.status == Status.Ok, requests.length == 1)
        }
      )
    ).provide(layers) @@ TestAspect.sequential
}
