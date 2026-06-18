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
  // The server resource is bound to the caller's Scope so it stays up for the request.
  private def stubServer(bodyRef: Ref[String]): ZIO[Scope & Server, Throwable, Int] =
    val routes = Routes(
      Method.GET / "v8" / "routes" -> handler { (_: Request) =>
        bodyRef.get.map(Response.json(_))
      }
    )
    Server.install(routes) *> ZIO.serviceWithZIO[Server](_.port)

  // A stub HERE Routing endpoint that returns an explicit HTTP status code.
  private def stubServerStatus(statusRef: Ref[Status], bodyRef: Ref[String]): ZIO[Scope & Server, Throwable, Int] =
    val routes = Routes(
      Method.GET / "v8" / "routes" -> handler { (_: Request) =>
        for {
          status <- statusRef.get
          body   <- bodyRef.get
        } yield Response(status = status, body = Body.fromString(body))
      }
    )
    Server.install(routes) *> ZIO.serviceWithZIO[Server](_.port)

  private val validBody = """{"routes":[{"sections":[{"summary":{"duration":125}}]}]}"""

  // An ephemeral-port (0) zio-http server layer for the stub HERE endpoint.
  private val serverLayer: ZLayer[Any, Throwable, Server] =
    ZLayer.succeed(Server.Config.default.port(0)) >>> Server.live

  def spec =
    suite("HereRoutingService")(
      test("returns None immediately when apiKey is empty (no HTTP call)") {
        (for {
          service <- makeService(HereConfig(apiKey = "", baseUrl = "http://127.0.0.1:1"))
          eta     <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
        } yield assertTrue(eta.isEmpty)).provide(Client.default, Scope.default)
      },
      test("parses the HERE summary duration into ceil(minutes)") {
        ZIO
          .scoped {
            for {
              bodyRef <- Ref.make(validBody)
              port    <- stubServer(bodyRef)
              service <- makeService(HereConfig(apiKey = "test-key", baseUrl = s"http://127.0.0.1:$port"))
              eta     <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
            } yield assertTrue(eta.contains(3)) // 125s -> ceil(125/60)=3
          }
          .provide(Client.default, serverLayer)
      },
      test("returns None when the response has no routes") {
        ZIO
          .scoped {
            for {
              bodyRef <- Ref.make("""{"routes":[]}""")
              port    <- stubServer(bodyRef)
              service <- makeService(HereConfig(apiKey = "k", baseUrl = s"http://127.0.0.1:$port"))
              eta     <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
            } yield assertTrue(eta.isEmpty)
          }
          .provide(Client.default, serverLayer)
      },
      test("returns None (handled) when the body is not valid HERE JSON") {
        ZIO
          .scoped {
            for {
              bodyRef <- Ref.make("""{"unexpected":true}""")
              port    <- stubServer(bodyRef)
              service <- makeService(HereConfig(apiKey = "k", baseUrl = s"http://127.0.0.1:$port"))
              eta     <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
            } yield assertTrue(eta.isEmpty)
          }
          .provide(Client.default, serverLayer)
      },
      // -----------------------------------------------------------------------
      // NEW: additional branch coverage
      // -----------------------------------------------------------------------
      test("returns None when response is non-2xx (HTTP 404)") {
        ZIO
          .scoped {
            for {
              statusRef <- Ref.make[Status](Status.NotFound)
              bodyRef   <- Ref.make("""{"error":"not found"}""")
              port      <- stubServerStatus(statusRef, bodyRef)
              service   <- makeService(HereConfig(apiKey = "k", baseUrl = s"http://127.0.0.1:$port"))
              eta       <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
            } yield assertTrue(eta.isEmpty)
          }
          .provide(Client.default, serverLayer)
      },
      test("returns None when the route has an empty sections list") {
        ZIO
          .scoped {
            for {
              bodyRef <- Ref.make("""{"routes":[{"sections":[]}]}""")
              port    <- stubServer(bodyRef)
              service <- makeService(HereConfig(apiKey = "k", baseUrl = s"http://127.0.0.1:$port"))
              eta     <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
            } yield assertTrue(eta.isEmpty)
          }
          .provide(Client.default, serverLayer)
      },
      test("uses first route when multiple routes are returned") {
        val multiRouteBody =
          """{"routes":[{"sections":[{"summary":{"duration":60}}]},{"sections":[{"summary":{"duration":300}}]}]}"""
        ZIO
          .scoped {
            for {
              bodyRef <- Ref.make(multiRouteBody)
              port    <- stubServer(bodyRef)
              service <- makeService(HereConfig(apiKey = "k", baseUrl = s"http://127.0.0.1:$port"))
              eta     <- service.getEtaMinutes(48.1, 11.5, 48.2, 11.6)
            } yield assertTrue(eta.contains(1)) // 60s -> ceil(1.0) = 1 min
          }
          .provide(Client.default, serverLayer)
      }
    ) @@ TestAspect.withLiveClock @@ TestAspect.sequential @@ TestAspect.timeout(30.seconds)

  // Build the service from its public layer (the impl class is private), reusing the
  // test-provided Client so its Netty event loop stays alive for the request below.
  private def makeService(config: HereConfig): ZIO[Client, Nothing, HereRoutingService] = ZIO
    .service[HereRoutingService]
    .provideSome[Client](HereRoutingService.layer, ZLayer.succeed(config))
