package com.shevchyk.app.openapi

import com.shevchyk.app.BuildInfo
import sttp.tapir.generic.auto.*
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*

/**
 * Public build/version endpoint.
 *
 * `GET /api/version` reports exactly which build is running — semver base, git commit/branch and build time — so prod
 * issues can be tied to a specific deploy and the Flutter app can show its own version next to the backend's. The
 * values come from the generated [[BuildInfo]] (baked at compile time via sbt-buildinfo + sbt-git), so they update
 * automatically every build with no manual stamping. Public (no bearer) so monitoring and the app can read it without a
 * token, like the guest-tracking endpoints in [[TrackApi]].
 */
object VersionApi:

  private val versionTag = "System"

  final case class VersionResponse(
      version: String,
      commit: String,
      branch: String,
      buildTime: String
  ) derives JsonCodec

  val versionEndpoint = endpoint.get
    .in("api" / "version")
    .out(jsonBody[VersionResponse])
    .tag(versionTag)
    .summary("Build/version info (public, no auth)")

  // Static: BuildInfo is a compile-time constant, so there is nothing to compute per request.
  private val response = VersionResponse(
    version = BuildInfo.version,
    commit = BuildInfo.gitShortCommit,
    branch = BuildInfo.gitBranch,
    buildTime = BuildInfo.buildTime
  )

  private val versionServer: ZServerEndpoint[Any, Any] = versionEndpoint.zServerLogic[Any](_ => ZIO.succeed(response))

  val serverEndpoints: List[ZServerEndpoint[Any, Any]] = List(versionServer)
