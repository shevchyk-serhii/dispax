package com.shevchyk.core.infrastructure

import com.shevchyk.core.infrastructure.http.RouteErrorHandler
import zio.*
import zio.http.*
import zio.test.*

object RouteErrorHandlerSpec extends ZIOSpecDefault {

  def spec =
    suite("RouteErrorHandler")(
      test("returns 500 Internal Server Error") {
        val ex = new RuntimeException("database gone")
        RouteErrorHandler.handleError("TestContext")(ex).map { response =>
          assertTrue(response.status == Status.InternalServerError)
        }
      },
      test("response body contains 'Internal server error'") {
        val ex = new RuntimeException("oops")
        for {
          response <- RouteErrorHandler.handleError("RideService")(ex)
          body     <- response.body.asString
        } yield assertTrue(body.contains("Internal server error"))
      },
      test("handles exception with null message") {
        val ex = new NullPointerException()
        RouteErrorHandler.handleError("NullCtx")(ex).map { response =>
          assertTrue(response.status == Status.InternalServerError)
        }
      },
      test("handles exception with message") {
        val ex = new IllegalStateException("bad state")
        RouteErrorHandler.handleError("StateCtx")(ex).map { response =>
          assertTrue(response.status == Status.InternalServerError)
        }
      }
    )
}
