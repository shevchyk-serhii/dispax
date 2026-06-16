package com.shevchyk.app.openapi

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.ride.application.service.AirportConfigService
import com.shevchyk.ride.domain.{Airport, AirportCheckpointZone}
import com.shevchyk.ride.repository.AirportConfigRepository
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * CRITICAL — Negative tenant-isolation and CRUD tests for SuperAdminAirportApi.
 *
 * Every handler in SuperAdminAirportApi starts with `requireSuperAdmin(user)`. These tests verify:
 *   - SuperAdmin JWT → success (200/201/204)
 *   - Admin / Dispatcher / Driver / Client JWT → 403 (all non-SuperAdmin roles denied)
 *   - No token → 401 (unauthenticated)
 *   - Basic CRUD round-trip via the in-memory AirportConfigService
 *
 * Routes are exercised via ZioHttpInterpreter against in-memory stubs — no network I/O.
 * This follows the identical pattern as [[SuperAdminApiSpec]].
 *
 * Testcontainers / real PostgreSQL coverage for the underlying repository is in
 * [[com.shevchyk.ride.integration.PostgresAirportConfigRepositorySpec]].
 */
object SuperAdminAirportApiSpec extends ZIOSpecDefault:

  // ---------------------------------------------------------------------------
  // JWT helpers (copied from SuperAdminApiSpec pattern)
  // ---------------------------------------------------------------------------

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-key-for-testing-only-not-for-production-must-be-at-least-256-bits",
      issuer = "test-issuer",
      audience = "test-audience",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(24L * 60 * 60 * 1_000_000_000L)
    )
  )

  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private val testCompanyId = UUID.fromString("10101010-1010-1010-1010-101010101010")

  private def generateToken(role: PersonRole, cid: Option[UUID]): ZIO[JwtService, Throwable, String] =
    ZIO.serviceWithZIO[JwtService](
      _.generateToken(
        Person(
          id = PersonId(UUID.randomUUID()),
          email = s"${role.toString.toLowerCase}@test.de",
          name = s"${role.toString} User",
          role = role,
          passwordHash = "hash",
          companyId = cid.map(CompanyId.apply),
          status = UserStatus.ACTIVE
        )
      )
    )

  // ---------------------------------------------------------------------------
  // In-memory AirportConfigRepository stub
  // ---------------------------------------------------------------------------

  private def makeInMemoryAirportRepo(): Task[AirportConfigRepository] =
    Ref.Synchronized.make(Map.empty[String, Airport]).map { stateRef =>
      new AirportConfigRepository:
        def findAll(): Task[List[Airport]] = stateRef.get.map(_.values.toList)
        def findByCode(code: String): Task[Option[Airport]] = stateRef.get.map(_.get(code))
        def create(airport: Airport): Task[Airport] = stateRef.update(_.updated(airport.code, airport)).as(airport)
        def update(code: String, airport: Airport): Task[Option[Airport]] =
          stateRef.get.flatMap { m =>
            if m.contains(code) then
              val u = airport.copy(code = code)
              stateRef.update(_.updated(code, u)).as(Some(u))
            else ZIO.succeed(None)
          }
        def delete(code: String): Task[Boolean] =
          stateRef.get.flatMap { m =>
            m.get(code).filter(_.isActive) match
              case None    => ZIO.succeed(false)
              case Some(a) => stateRef.update(_.updated(code, a.copy(isActive = false))).as(true)
          }
        def createZone(zone: AirportCheckpointZone): Task[AirportCheckpointZone] =
          stateRef.get.flatMap { m =>
            m.get(zone.airportCode) match
              case None    => ZIO.fail(new RuntimeException(s"Airport not found: ${zone.airportCode}"))
              case Some(a) =>
                val z = zone.copy(id = UUID.randomUUID())
                stateRef.update(_.updated(a.code, a.copy(zones = a.zones :+ z))).as(z)
          }
        def updateZone(id: UUID, zone: AirportCheckpointZone): Task[Option[AirportCheckpointZone]] =
          stateRef.get.flatMap { m =>
            m.values.find(_.zones.exists(_.id == id)) match
              case None    => ZIO.succeed(None)
              case Some(a) =>
                val u = zone.copy(id = id, airportCode = a.code)
                stateRef.update(_.updated(a.code, a.copy(zones = a.zones.map(z => if z.id == id then u else z)))).as(Some(u))
          }
        def deleteZone(id: UUID): Task[Boolean] =
          stateRef.get.flatMap { m =>
            m.values.find(_.zones.exists(_.id == id)) match
              case None    => ZIO.succeed(false)
              case Some(a) => stateRef.update(_.updated(a.code, a.copy(zones = a.zones.filterNot(_.id == id)))).as(true)
          }
    }

  // ---------------------------------------------------------------------------
  // Layer wiring
  // ---------------------------------------------------------------------------

  private val stubAirportConfigServiceLayer: ZLayer[Any, Throwable, AirportConfigService] =
    ZLayer.fromZIO(makeInMemoryAirportRepo()) >>> AirportConfigService.layer

  private type TestEnv = SuperAdminAirportApi.SuperAdminAirportEnv

  private val testLayers: ZLayer[Any, Throwable, TestEnv] =
    testJwtService ++ stubAirportConfigServiceLayer

  // ---------------------------------------------------------------------------
  // Route runner helper
  // ---------------------------------------------------------------------------

  private val airportRoutes: Routes[SuperAdminAirportApi.SuperAdminAirportEnv, Response] =
    ZioHttpInterpreter().toHttp(SuperAdminAirportApi.serverEndpoints)

  private def run(req: Request): ZIO[SuperAdminAirportApi.SuperAdminAirportEnv, Nothing, Response] =
    airportRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  // ---------------------------------------------------------------------------
  // Shared fixture airport JSON
  // ---------------------------------------------------------------------------

  private val createMucBody =
    """{"code":"MUC","name":"München Franz Josef Strauß","country":"DE","landingLat":48.3537,"landingLon":11.7860,"landingRadius":2000}"""

  private def jsonReq(method: Method, path: String, body: Option[String] = None): Request =
    body match
      case None    => Request(method = method, url = URL.decode(path).toOption.get)
      case Some(b) =>
        Request(method = method, url = URL.decode(path).toOption.get, body = Body.fromString(b))
          .addHeader(Header.ContentType(MediaType.application.json))

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  def spec =
    suite("SuperAdminAirportApi [CRITICAL security]")(

      // -----------------------------------------------------------------------
      // GET /api/superadmin/airports  — list
      // -----------------------------------------------------------------------
      suite("GET /api/superadmin/airports")(
        test("SuperAdmin JWT → 200") {
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            req    = jsonReq(Method.GET, "/api/superadmin/airports")
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Ok)
        },
        test("Admin JWT → 403 [CRITICAL]") {
          for {
            token <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            req    = jsonReq(Method.GET, "/api/superadmin/airports")
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("Dispatcher JWT → 403 [CRITICAL]") {
          for {
            token <- generateToken(PersonRole.Dispatcher, cid = Some(testCompanyId))
            req    = jsonReq(Method.GET, "/api/superadmin/airports")
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("Driver JWT → 403 [CRITICAL]") {
          for {
            token <- generateToken(PersonRole.Driver, cid = Some(testCompanyId))
            req    = jsonReq(Method.GET, "/api/superadmin/airports")
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("Client JWT → 403 [CRITICAL]") {
          for {
            token <- generateToken(PersonRole.Client, cid = Some(testCompanyId))
            req    = jsonReq(Method.GET, "/api/superadmin/airports")
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("no token → 401") {
          val req = jsonReq(Method.GET, "/api/superadmin/airports")
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        }
      ),

      // -----------------------------------------------------------------------
      // POST /api/superadmin/airports  — create
      // -----------------------------------------------------------------------
      suite("POST /api/superadmin/airports")(
        test("SuperAdmin JWT → 201 Created") {
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            req    = jsonReq(Method.POST, "/api/superadmin/airports", Some(createMucBody))
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Created)
        },
        test("Admin JWT → 403 on create [CRITICAL]") {
          for {
            token <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            req    = jsonReq(Method.POST, "/api/superadmin/airports", Some(createMucBody))
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("Dispatcher JWT → 403 on create [CRITICAL]") {
          for {
            token <- generateToken(PersonRole.Dispatcher, cid = Some(testCompanyId))
            req    = jsonReq(Method.POST, "/api/superadmin/airports", Some(createMucBody))
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("no token → 401 on create") {
          val req = jsonReq(Method.POST, "/api/superadmin/airports", Some(createMucBody))
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        }
      ),

      // -----------------------------------------------------------------------
      // GET /api/superadmin/airports/{code}  — get by code
      // -----------------------------------------------------------------------
      suite("GET /api/superadmin/airports/{code}")(
        test("SuperAdmin JWT + existing airport → 200 with correct code in body") {
          for {
            token   <- generateToken(PersonRole.SuperAdmin, cid = None)
            // First create the airport
            createReq = jsonReq(Method.POST, "/api/superadmin/airports", Some(createMucBody))
                          .addHeader(Header.Authorization.Bearer(token))
            _       <- run(createReq)
            // Then GET it
            getReq   = jsonReq(Method.GET, "/api/superadmin/airports/MUC")
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- run(getReq)
            bodyStr <- resp.body.asString
          } yield assertTrue(
            resp.status == Status.Ok,
            bodyStr.contains("\"code\":\"MUC\"")
          )
        },
        test("SuperAdmin JWT + unknown code → 404") {
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            req    = jsonReq(Method.GET, "/api/superadmin/airports/UNKNOWN")
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.NotFound)
        },
        test("Admin JWT → 403 on get-by-code [CRITICAL]") {
          for {
            token <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            req    = jsonReq(Method.GET, "/api/superadmin/airports/MUC")
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),

      // -----------------------------------------------------------------------
      // PATCH /api/superadmin/airports/{code}  — update
      // -----------------------------------------------------------------------
      suite("PATCH /api/superadmin/airports/{code}")(
        test("SuperAdmin JWT → 200 with updated fields reflected") {
          for {
            token    <- generateToken(PersonRole.SuperAdmin, cid = None)
            createReq = jsonReq(Method.POST, "/api/superadmin/airports", Some(createMucBody))
                          .addHeader(Header.Authorization.Bearer(token))
            _        <- run(createReq)
            patchBody = """{"name":"MUC Updated","landingRadius":2500}"""
            patchReq  = jsonReq(Method.PATCH, "/api/superadmin/airports/MUC", Some(patchBody))
                          .addHeader(Header.Authorization.Bearer(token))
            resp     <- run(patchReq)
            bodyStr  <- resp.body.asString
          } yield assertTrue(
            resp.status == Status.Ok,
            bodyStr.contains("MUC Updated"),
            bodyStr.contains("2500")
          )
        },
        test("Admin JWT → 403 on update [CRITICAL]") {
          for {
            token    <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            patchBody = """{"name":"Hacked Name"}"""
            req       = jsonReq(Method.PATCH, "/api/superadmin/airports/MUC", Some(patchBody))
                          .addHeader(Header.Authorization.Bearer(token))
            resp     <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("Dispatcher JWT → 403 on update [CRITICAL]") {
          for {
            token    <- generateToken(PersonRole.Dispatcher, cid = Some(testCompanyId))
            patchBody = """{"name":"Hacked"}"""
            req       = jsonReq(Method.PATCH, "/api/superadmin/airports/MUC", Some(patchBody))
                          .addHeader(Header.Authorization.Bearer(token))
            resp     <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),

      // -----------------------------------------------------------------------
      // DELETE /api/superadmin/airports/{code}  — soft-delete
      // -----------------------------------------------------------------------
      suite("DELETE /api/superadmin/airports/{code}")(
        test("SuperAdmin JWT + existing airport → 200 with isActive=false in body") {
          for {
            token     <- generateToken(PersonRole.SuperAdmin, cid = None)
            createReq  = jsonReq(Method.POST, "/api/superadmin/airports", Some(createMucBody))
                           .addHeader(Header.Authorization.Bearer(token))
            _         <- run(createReq)
            deleteReq  = jsonReq(Method.DELETE, "/api/superadmin/airports/MUC")
                           .addHeader(Header.Authorization.Bearer(token))
            resp      <- run(deleteReq)
            bodyStr   <- resp.body.asString
          } yield assertTrue(
            resp.status == Status.Ok,
            bodyStr.contains("\"isActive\":false")
          )
        },
        test("Admin JWT → 403 on delete [CRITICAL]") {
          for {
            token <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            req    = jsonReq(Method.DELETE, "/api/superadmin/airports/MUC")
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("Driver JWT → 403 on delete [CRITICAL]") {
          for {
            token <- generateToken(PersonRole.Driver, cid = Some(testCompanyId))
            req    = jsonReq(Method.DELETE, "/api/superadmin/airports/MUC")
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("no token → 401 on delete") {
          val req = jsonReq(Method.DELETE, "/api/superadmin/airports/MUC")
          run(req).map(resp => assertTrue(resp.status == Status.Unauthorized))
        }
      ),

      // -----------------------------------------------------------------------
      // POST /api/superadmin/airports/{code}/zones  — create zone
      // -----------------------------------------------------------------------
      suite("POST /api/superadmin/airports/{code}/zones")(
        test("SuperAdmin JWT → 201 Created") {
          for {
            token      <- generateToken(PersonRole.SuperAdmin, cid = None)
            createReq   = jsonReq(Method.POST, "/api/superadmin/airports", Some(createMucBody))
                            .addHeader(Header.Authorization.Bearer(token))
            _          <- run(createReq)
            zoneBody    =
              """{"airportCode":"MUC","terminalCode":"T1","checkpointType":"arrivals_hall","displayName":"T1 Arrivals Hall","lat":48.3526,"lon":11.7798,"radiusMeters":200,"sortOrder":1}"""
            zoneReq     = jsonReq(Method.POST, "/api/superadmin/airports/MUC/zones", Some(zoneBody))
                            .addHeader(Header.Authorization.Bearer(token))
            resp       <- run(zoneReq)
            bodyStr    <- resp.body.asString
          } yield assertTrue(
            resp.status == Status.Created,
            bodyStr.contains("T1 Arrivals Hall")
          )
        },
        test("Admin JWT → 403 on create zone [CRITICAL]") {
          for {
            token   <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            zoneBody =
              """{"airportCode":"MUC","terminalCode":"T1","checkpointType":"arrivals_hall","displayName":"T1 Arrivals Hall","lat":48.3526,"lon":11.7798,"radiusMeters":200,"sortOrder":1}"""
            req      = jsonReq(Method.POST, "/api/superadmin/airports/MUC/zones", Some(zoneBody))
                         .addHeader(Header.Authorization.Bearer(token))
            resp    <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("invalid checkpoint type → 400 Bad Request") {
          for {
            token      <- generateToken(PersonRole.SuperAdmin, cid = None)
            createReq   = jsonReq(Method.POST, "/api/superadmin/airports", Some(createMucBody))
                            .addHeader(Header.Authorization.Bearer(token))
            _          <- run(createReq)
            zoneBody    =
              """{"airportCode":"MUC","terminalCode":"T1","checkpointType":"INVALID_TYPE","displayName":"X","lat":48.3526,"lon":11.7798,"radiusMeters":200,"sortOrder":1}"""
            zoneReq     = jsonReq(Method.POST, "/api/superadmin/airports/MUC/zones", Some(zoneBody))
                            .addHeader(Header.Authorization.Bearer(token))
            resp       <- run(zoneReq)
          } yield assertTrue(resp.status == Status.BadRequest)
        }
      ),

      // -----------------------------------------------------------------------
      // DELETE /api/superadmin/airports/{code}/zones/{zoneId}  — delete zone
      // -----------------------------------------------------------------------
      suite("DELETE /api/superadmin/airports/{code}/zones/{zoneId}")(
        test("SuperAdmin JWT → 204 No Content after creating and deleting zone") {
          for {
            token      <- generateToken(PersonRole.SuperAdmin, cid = None)
            // Create airport
            createReq   = jsonReq(Method.POST, "/api/superadmin/airports", Some(createMucBody))
                            .addHeader(Header.Authorization.Bearer(token))
            _          <- run(createReq)
            // Create zone
            zoneBody    =
              """{"airportCode":"MUC","terminalCode":"T1","checkpointType":"terminal_exit","displayName":"T1 Exit","lat":48.3515,"lon":11.7793,"radiusMeters":150,"sortOrder":2}"""
            zoneReq     = jsonReq(Method.POST, "/api/superadmin/airports/MUC/zones", Some(zoneBody))
                            .addHeader(Header.Authorization.Bearer(token))
            zoneResp   <- run(zoneReq)
            zoneBody2  <- zoneResp.body.asString
            // Extract zone ID from response
            zoneIdOpt   = zoneBody2.split("\"id\":\"").drop(1).headOption.map(_.takeWhile(_ != '"'))
            zoneId      = zoneIdOpt.getOrElse("missing-id")
            // Delete zone
            deleteReq   = jsonReq(Method.DELETE, s"/api/superadmin/airports/MUC/zones/$zoneId")
                            .addHeader(Header.Authorization.Bearer(token))
            deleteResp <- run(deleteReq)
          } yield assertTrue(
            zoneResp.status == Status.Created,
            zoneIdOpt.isDefined,
            deleteResp.status == Status.NoContent
          )
        },
        test("Admin JWT → 403 on delete zone [CRITICAL]") {
          for {
            token  <- generateToken(PersonRole.Admin, cid = Some(testCompanyId))
            fakeId  = UUID.randomUUID().toString
            req     = jsonReq(Method.DELETE, s"/api/superadmin/airports/MUC/zones/$fakeId")
                        .addHeader(Header.Authorization.Bearer(token))
            resp   <- run(req)
          } yield assertTrue(resp.status == Status.Forbidden)
        }
      ),

      // -----------------------------------------------------------------------
      // Validation tests
      // -----------------------------------------------------------------------
      suite("Input validation")(
        test("latitude out of range → 400") {
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            body   =
              """{"code":"BAD","name":"Bad Airport","country":"DE","landingLat":91.0,"landingLon":11.0,"landingRadius":1000}"""
            req    = jsonReq(Method.POST, "/api/superadmin/airports", Some(body))
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.BadRequest)
        },
        test("negative radius → 400") {
          for {
            token <- generateToken(PersonRole.SuperAdmin, cid = None)
            body   =
              """{"code":"BAD","name":"Bad Airport","country":"DE","landingLat":48.0,"landingLon":11.0,"landingRadius":-1}"""
            req    = jsonReq(Method.POST, "/api/superadmin/airports", Some(body))
                       .addHeader(Header.Authorization.Bearer(token))
            resp  <- run(req)
          } yield assertTrue(resp.status == Status.BadRequest)
        }
      )

    ).provide(testLayers) @@ TestAspect.sequential
