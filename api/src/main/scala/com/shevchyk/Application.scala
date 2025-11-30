package com.shevchyk

import zio.*
import zio.http.*
import zio.logging.backend.SLF4J

object Application extends ZIOAppDefault:

  private val routes = Routes(
    Method.GET / "hello"         -> handler(Response.text("Hello World!")),
    Method.GET / "api" / "users" -> handler(Response.json("""[{"id": 1, "name": "John"}]"""))
  )

  override val bootstrap: ZLayer[ZIOAppArgs, Any, Any] = Runtime.removeDefaultLoggers >>> SLF4J.slf4j

  def run = Server.serve(routes).provide(Server.default)
