package com.shevchyk.app.openapi

import com.shevchyk.app.BuildInfo
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*

/**
 * Guards the public build/version endpoint. `GET /api/version` must return 200 with a JSON body whose fields mirror the
 * generated [[BuildInfo]] (so a deployed build self-reports its real semver + git commit/branch). Driving the real
 * endpoint through the zio-http interpreter (as TrackApiSpec does) covers the wiring, not just the DTO. A regression
 * that stubs the response or drops a field turns this red.
 */
object VersionApiSpec extends ZIOSpecDefault:

  private val routes = ZioHttpInterpreter().toHttp(VersionApi.serverEndpoints)

  def spec =
    suite("VersionApiSpec")(
      test("GET /api/version returns 200 with the BuildInfo values") {
        for {
          resp <- routes.runZIO(Request.get(URL.decode("/api/version").toOption.get))
          body <- resp.body.asString
          dto  <- ZIO.fromEither(body.fromJson[VersionApi.VersionResponse]).mapError(new RuntimeException(_))
        } yield assertTrue(
          resp.status == Status.Ok,
          dto.version == BuildInfo.version,
          dto.commit == BuildInfo.gitShortCommit,
          dto.branch == BuildInfo.gitBranch,
          dto.buildTime == BuildInfo.buildTime,
          // The values are really baked in, not empty placeholders.
          dto.version.nonEmpty,
          dto.commit.nonEmpty,
          // API contract version drives client/server compatibility + force-update.
          // Pinned to literals: the endpoint must actually carry these, and a
          // contract bump is a deliberate change that should update this test.
          dto.apiVersion == 1,
          dto.minClientVersion == 1
        )
      }
    )
