package com.shevchyk.driver.application

import com.shevchyk.core.config.HereConfig
import zio.*
import zio.http.*
import zio.test.*

/**
 * Tests for HereRoutingService. A local zio-http test server stands in for the HERE Routing API so the request/parse
 * path runs end-to-end without network access, plus the short-circuit (empty apiKey) and error-handling branches.
 */
object HereRoutingServiceSpec extends ZIOSpecDefault:

  // A stub HERE Routing endpoint whose response body is controlled per test via a Ref.
  private def stubServer(bodyRef: Ref[String]): ZIO[Scope, Throwable, Int] =
    val routes = Routes(
      Method.GET / "v8" / "routes" -> handler { (_: Request) =>
        bodyRef.get.map(Response.json(_))
      }
    )
    for {
      port <- Server.install(routes).provideSome[Scope](Server.live, ZLayer.succeed(Server.Config.default.port(0)))
    } yield port

  private val validBody = """{"routes":[{"sections":[{"summary":{"duration":125}}]}]}"""

  def spec =
    suite("HereRoutingService")(
      test("returns None immediately when apiKey is empty (no HTTP call)") {
        (for {
          config  <- ZIO.succeed(HereConfig(apiKey = "", baseUrl = "http://127.0.0.1:1"))
          service <- ZIO.succeed(makeService(config))
          eta     <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
        } yield assertTrue(eta.isEmpty)).provide(Client.default, Scope.default)
      },
      test("parses the HERE summary duration into ceil(minutes)") {
        ZIO
          .scoped {
            for {
              bodyRef <- Ref.make(validBody)
              port    <- stubServer(bodyRef)
              config   = HereConfig(apiKey = "test-key", baseUrl = s"http://127.0.0.1:$port")
              service  = makeService(config)
              eta     <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
            } yield assertTrue(eta.contains(3)) // 125s -> ceil(125/60)=3
          }
          .provide(Client.default)
      },
      test("returns None when the response has no routes") {
        ZIO
          .scoped {
            for {
              bodyRef <- Ref.make("""{"routes":[]}""")
              port    <- stubServer(bodyRef)
              config   = HereConfig(apiKey = "k", baseUrl = s"http://127.0.0.1:$port")
              service  = makeService(config)
              eta     <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
            } yield assertTrue(eta.isEmpty)
          }
          .provide(Client.default)
      },
      test("returns None (handled) when the body is not valid HERE JSON") {
        ZIO
          .scoped {
            for {
              bodyRef <- Ref.make("""{"unexpected":true}""")
              port    <- stubServer(bodyRef)
              config   = HereConfig(apiKey = "k", baseUrl = s"http://127.0.0.1:$port")
              service  = makeService(config)
              eta     <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
            } yield assertTrue(eta.isEmpty)
          }
          .provide(Client.default)
      }
    ) @@ TestAspect.withLiveClock @@ TestAspect.sequential

  // Build the service from its public layer (the impl class is private).
  private def makeService(config: HereConfig): HereRoutingService = Unsafe.unsafe { implicit u =>
    Runtime.default.unsafe
      .run(
        ZIO
          .service[HereRoutingService]
          .provide(HereRoutingService.layer, ZLayer.succeed(config), Client.default)
      )
      .getOrThrowFiberFailure()
  }
