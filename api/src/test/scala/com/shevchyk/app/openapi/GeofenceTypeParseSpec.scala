package com.shevchyk.app.openapi

import java.util.UUID

import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import com.shevchyk.core.application.{EventHub, GeofenceService}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{GeofenceRepository, InMemoryGeofenceRepository, InMemoryPersonRepository}

/**
 * Endpoint-level tests for the `geofenceType` parsing on POST/PUT /api/geofences.
 *
 * Regression coverage for the audit finding: `GeofenceType.valueOf(req.geofenceType)` throws `IllegalArgumentException`
 * on an unknown value and the handler mapped it to a 500 — plain bad input must be a 400. Runs the REAL
 * `GeofenceApi.serverEndpoints` through `ZioHttpInterpreter`.
 */
object GeofenceTypeParseSpec extends ZIOSpecDefault:

  private val companyId  = CompanyId(UUID.fromString("000000AB-0000-0000-0000-000000000001"))
  private val geofenceId = GeofenceId(UUID.fromString("000000FE-0000-0000-0000-000000000001"))

  private val seededGeofence: Geofence = Geofence(
    id = geofenceId,
    companyId = companyId,
    name = "Munich Airport",
    geofenceType = GeofenceType.Airport,
    centerLatitude = 48.3538,
    centerLongitude = 11.7861,
    radiusMeters = 500,
    notifyOnEntry = true,
    notifyOnExit = false
  )

  private def buildLayers(repo: GeofenceRepository): ZLayer[Any, Throwable, GeofenceApi.GeofenceEnv] =
    val repoLayer = ZLayer.succeed(repo)
    TestJwt.serviceLayer ++ repoLayer ++ ((repoLayer ++ EventHub.layer) >>> GeofenceService.layer) ++
      InMemoryPersonRepository.layer

  private def run(
      req: Request,
      layers: ZLayer[Any, Throwable, GeofenceApi.GeofenceEnv]
  ): ZIO[Any, Throwable, Response] = ZioHttpInterpreter()
    .toHttp(GeofenceApi.serverEndpoints)
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }
    .provideLayer(layers)

  private def jsonReq(method: Method, path: String, token: String, geofenceType: String): Request = Request(
    method = method,
    url = URL.decode(path).toOption.get,
    body = Body.fromString(
      s"""{"name":"Zone","geofenceType":"$geofenceType","centerLatitude":48.35,"centerLongitude":11.78,"radiusMeters":300}"""
    )
  )
    .addHeader(Header.Authorization.Bearer(token))
    .addHeader(Header.ContentType(zio.http.MediaType.application.json))

  private def token: ZIO[Any, Throwable, String] = TestJwt
    .generateToken(PersonRole.Dispatcher, companyId)
    .provideLayer(TestJwt.serviceLayer)

  private def freshRepo: ZIO[Any, Throwable, GeofenceRepository] =
    val repo = new InMemoryGeofenceRepository
    repo.create(seededGeofence).as(repo)

  def spec =
    suite("GeofenceApi — geofenceType parsing [real serverEndpoints]")(
      test("creating a geofence with an unknown type → 400 (not 500)") {
        for {
          repo <- freshRepo
          t    <- token
          resp <- run(jsonReq(Method.POST, "/api/geofences", t, "NotAType"), buildLayers(repo))
        } yield assertTrue(resp.status == Status.BadRequest)
      },
      test("updating a geofence with an unknown type → 400 (not 500)") {
        for {
          repo <- freshRepo
          t    <- token
          resp <- run(jsonReq(Method.PUT, s"/api/geofences/${geofenceId.value}", t, "NotAType"), buildLayers(repo))
        } yield assertTrue(resp.status == Status.BadRequest)
      },
      test("creating a geofence with a valid type still works → 201") {
        for {
          repo <- freshRepo
          t    <- token
          resp <- run(jsonReq(Method.POST, "/api/geofences", t, "Airport"), buildLayers(repo))
        } yield assertTrue(resp.status == Status.Created)
      }
    ) @@ TestAspect.sequential
