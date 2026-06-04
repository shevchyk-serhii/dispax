package com.shevchyk.app.routes

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{GeofenceService, EventHub}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{GeofenceRepository, InMemoryGeofenceRepository}
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*
import java.time.Instant
import java.util.UUID

object GeofenceRoutesSpec extends ZIOSpecDefault {

  private val taxiCompanyId  = UUID.fromString("00000000-0000-0000-0000-000000000010")
  private val otherCompanyId = UUID.fromString("00000000-0000-0000-0000-000000000099")
  private val dispatcherId   = UUID.fromString("00000000-0000-0000-0000-000000000001")
  private val driverId       = UUID.fromString("00000000-0000-0000-0000-000000000002")

  private val testJwtLayer: ZLayer[Any, Nothing, JwtService] =
    ZLayer.succeed(JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
    )) >>> JwtService.live

  private def generateToken(
      userId: UUID,
      role: PersonRole = PersonRole.Dispatcher,
      companyId: Option[UUID] = Some(taxiCompanyId)
  ): ZIO[JwtService, Throwable, String] =
    ZIO.serviceWithZIO[JwtService](_.generateToken(Person(
      id = PersonId(userId),
      email = s"$userId@test.com",
      name = "Test User",
      role = role,
      passwordHash = "hash",
      companyId = companyId.map(CompanyId.apply),
      status = UserStatus.ACTIVE
    )))

  private def runRequest(req: Request): ZIO[GeofenceRepository & GeofenceService & JwtService, Nothing, Response] =
    GeofenceRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private def makeGeofence(companyId: UUID = taxiCompanyId, name: String = "Airport Zone"): Geofence =
    Geofence(
      id = GeofenceId.generate(),
      companyId = CompanyId(companyId),
      name = name,
      geofenceType = GeofenceType.Airport,
      centerLatitude = 50.45,
      centerLongitude = 30.52,
      radiusMeters = 500,
      notifyOnEntry = true,
      notifyOnExit = false
    )

  private val layers =
    (GeofenceRepository.inMemory ++ EventHub.layer) >+> GeofenceService.layer ++
    testJwtLayer

  def spec = suite("GeofenceRoutes")(

    suite("POST /api/geofences")(
      test("dispatcher creates geofence successfully") {
        for {
          token   <- generateToken(dispatcherId)
          body     = """{"name":"Service Area","geofenceType":"ServiceArea","centerLatitude":50.45,"centerLongitude":30.52,"radiusMeters":1000,"notifyOnEntry":true,"notifyOnExit":true}"""
          request  = Request.post(URL.decode("/api/geofences").toOption.get, Body.fromString(body))
                       .addHeader(Header.Authorization.Bearer(token))
          resp    <- runRequest(request)
          bodyStr <- resp.body.asString.orDie
          created <- ZIO.fromEither(bodyStr.fromJson[Geofence]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(
          resp.status == Status.Created,
          created.name == "Service Area",
          created.companyId == CompanyId(taxiCompanyId)
        )
      },

      test("returns error for invalid geofence type") {
        for {
          token   <- generateToken(dispatcherId)
          body     = """{"name":"Zone","geofenceType":"InvalidType","centerLatitude":50.0,"centerLongitude":30.0,"radiusMeters":100,"notifyOnEntry":true,"notifyOnExit":false}"""
          request  = Request.post(URL.decode("/api/geofences").toOption.get, Body.fromString(body))
                       .addHeader(Header.Authorization.Bearer(token))
          resp    <- runRequest(request)
        } yield assertTrue(resp.status != Status.Created)
      },

      test("returns 401 without token") {
        for {
          body <- ZIO.succeed("""{"name":"Zone","geofenceType":"Airport","centerLatitude":50.0,"centerLongitude":30.0,"radiusMeters":100,"notifyOnEntry":true,"notifyOnExit":false}""")
          resp <- runRequest(Request.post(URL.decode("/api/geofences").toOption.get, Body.fromString(body)))
        } yield assertTrue(resp.status == Status.Unauthorized)
      },

      test("returns 403 for driver role") {
        for {
          token   <- generateToken(driverId, role = PersonRole.Driver)
          body     = """{"name":"Zone","geofenceType":"Airport","centerLatitude":50.0,"centerLongitude":30.0,"radiusMeters":100,"notifyOnEntry":true,"notifyOnExit":false}"""
          request  = Request.post(URL.decode("/api/geofences").toOption.get, Body.fromString(body))
                       .addHeader(Header.Authorization.Bearer(token))
          resp    <- runRequest(request)
        } yield assertTrue(resp.status == Status.Forbidden)
      }
    ),

    suite("GET /api/geofences")(
      test("dispatcher gets list for own company") {
        for {
          repo  <- ZIO.service[GeofenceRepository]
          _     <- repo.create(makeGeofence())
          _     <- repo.create(makeGeofence(companyId = otherCompanyId, name = "Other Zone"))
          token <- generateToken(dispatcherId)
          resp  <- runRequest(
                     Request.get(URL.decode("/api/geofences").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
          bodyStr <- resp.body.asString.orDie
          list    <- ZIO.fromEither(bodyStr.fromJson[List[Geofence]]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(resp.status == Status.Ok, list.length == 1, list.head.name == "Airport Zone")
      },

      test("returns 401 without token") {
        for {
          resp <- runRequest(Request.get(URL.decode("/api/geofences").toOption.get))
        } yield assertTrue(resp.status == Status.Unauthorized)
      }
    ),

    suite("PUT /api/geofences/:id")(
      test("updates geofence for same company") {
        for {
          repo    <- ZIO.service[GeofenceRepository]
          gf      <- repo.create(makeGeofence())
          token   <- generateToken(dispatcherId)
          body     = s"""{"name":"Updated Zone","geofenceType":"Airport","centerLatitude":51.0,"centerLongitude":31.0,"radiusMeters":200,"notifyOnEntry":false,"notifyOnExit":true}"""
          request  = Request.put(URL.decode(s"/api/geofences/${gf.id.value}").toOption.get, Body.fromString(body))
                       .addHeader(Header.Authorization.Bearer(token))
          resp    <- runRequest(request)
          bodyStr <- resp.body.asString.orDie
          updated <- ZIO.fromEither(bodyStr.fromJson[Geofence]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(resp.status == Status.Ok, updated.name == "Updated Zone")
      },

      test("returns error for geofence of different company") {
        for {
          repo    <- ZIO.service[GeofenceRepository]
          gf      <- repo.create(makeGeofence(companyId = otherCompanyId))
          token   <- generateToken(dispatcherId)
          body     = """{"name":"Hack","geofenceType":"Airport","centerLatitude":0.0,"centerLongitude":0.0,"radiusMeters":1,"notifyOnEntry":false,"notifyOnExit":false}"""
          request  = Request.put(URL.decode(s"/api/geofences/${gf.id.value}").toOption.get, Body.fromString(body))
                       .addHeader(Header.Authorization.Bearer(token))
          resp    <- runRequest(request)
        } yield assertTrue(resp.status != Status.Ok)
      }
    ),

    suite("DELETE /api/geofences/:id")(
      test("deletes geofence for same company") {
        for {
          repo  <- ZIO.service[GeofenceRepository]
          gf    <- repo.create(makeGeofence())
          token <- generateToken(dispatcherId)
          resp  <- runRequest(
                     Request.delete(URL.decode(s"/api/geofences/${gf.id.value}").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
          gone  <- repo.findById(gf.id)
        } yield assertTrue(resp.status == Status.NoContent, gone.isEmpty)
      },

      test("returns error for geofence of different company") {
        for {
          repo  <- ZIO.service[GeofenceRepository]
          gf    <- repo.create(makeGeofence(companyId = otherCompanyId))
          token <- generateToken(dispatcherId)
          resp  <- runRequest(
                     Request.delete(URL.decode(s"/api/geofences/${gf.id.value}").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
        } yield assertTrue(resp.status != Status.NoContent)
      }
    ),

    suite("GET /api/geofences/alerts")(
      test("returns alerts for company") {
        for {
          repo  <- ZIO.service[GeofenceRepository]
          gf    <- repo.create(makeGeofence())
          alert  = GeofenceAlert(
                     id = UUID.randomUUID(),
                     geofenceId = gf.id,
                     driverId = PersonId(driverId),
                     companyId = CompanyId(taxiCompanyId),
                     alertType = "entry",
                     geofenceName = gf.name,
                     latitude = 50.45,
                     longitude = 30.52,
                     timestamp = Instant.now()
                   )
          _     <- repo.saveAlert(alert)
          token <- generateToken(dispatcherId)
          resp  <- runRequest(
                     Request.get(URL.decode("/api/geofences/alerts").toOption.get)
                       .addHeader(Header.Authorization.Bearer(token))
                   )
          bodyStr <- resp.body.asString.orDie
          list    <- ZIO.fromEither(bodyStr.fromJson[List[GeofenceAlert]]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(resp.status == Status.Ok, list.length == 1)
      }
    ),

    suite("GET /api/geofences/alerts/driver/:driverId")(
      test("returns alerts for specific driver") {
        for {
          repo      <- ZIO.service[GeofenceRepository]
          gf        <- repo.create(makeGeofence())
          driverPid  = UUID.fromString("00000000-0000-0000-0000-000000000002")
          otherPid   = UUID.fromString("00000000-0000-0000-0000-000000000003")
          alert1     = GeofenceAlert(UUID.randomUUID(), gf.id, PersonId(driverPid), CompanyId(taxiCompanyId), "entry", gf.name, 50.0, 30.0, Instant.now())
          alert2     = GeofenceAlert(UUID.randomUUID(), gf.id, PersonId(otherPid), CompanyId(taxiCompanyId), "exit", gf.name, 50.1, 30.1, Instant.now())
          _         <- repo.saveAlert(alert1)
          _         <- repo.saveAlert(alert2)
          token     <- generateToken(dispatcherId)
          resp      <- runRequest(
                         Request.get(URL.decode(s"/api/geofences/alerts/driver/$driverPid").toOption.get)
                           .addHeader(Header.Authorization.Bearer(token))
                       )
          bodyStr   <- resp.body.asString.orDie
          list      <- ZIO.fromEither(bodyStr.fromJson[List[GeofenceAlert]]).mapError(new RuntimeException(_)).orDie
        } yield assertTrue(resp.status == Status.Ok, list.length == 1, list.head.driverId == PersonId(driverPid))
      }
    )

  ).provide(layers) @@ TestAspect.sequential
}
