package com.shevchyk.app.routes

import com.shevchyk.service.AuthService
import com.shevchyk.domain.LoginRequest
import RouteHelpers.*
import zio.*
import zio.http.*
import zio.json.*

object AuthRoutes {

  val routes = Routes(
    
    Method.POST / "api" / "auth" / "login" ->
      badRequestEndpoint("Invalid login data") { req =>
        for
          body        <- req.body.asString
          loginReq    <- ZIO.fromEither(body.fromJson[LoginRequest])
          authService <- ZIO.service[AuthService]
          loginResp   <- authService.login(loginReq)
        yield handleOptionalResult(loginResp).status(
          if (loginResp.isDefined)
            Status.Ok
          else
            Status.Unauthorized
        )
      },
    Method.GET / "api" / "auth" / "me"     ->
      authEndpoint { req =>
        for
          token       <- extractAuthToken(req)
          authService <- ZIO.service[AuthService]
          person      <- authService.validateToken(token)
        yield handleOptionalResult(person).status(
          if (person.isDefined)
            Status.Ok
          else
            Status.Unauthorized
        )
      },
    Method.GET / "api" / "persons"         ->
      safeEndpoint {
        for
          authService <- ZIO.service[AuthService]
          persons     <- authService.getAllPersons
        yield jsonResponse(persons)
      }
  )
}
