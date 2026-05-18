package com.shevchyk.ride.infrastructure.http

import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.PersonId
import com.shevchyk.ride.domain.{ClientAddressId, SaveClientAddressRequest}
import com.shevchyk.ride.application.service.ClientAddressService
import zio.*
import zio.http.*
import zio.json.*

import java.util.UUID

object ClientAddressRoutes:

  private def handleError(ex: Throwable): UIO[Response] =
    val msg = Option(ex.getMessage).getOrElse(ex.toString)
    ZIO
      .logError(s"ClientAddress error: $msg")
      .as(Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}""")))

  val authenticatedRoutes: Routes[ClientAddressService & JwtService, Response] = Routes(
    // GET /api/clients/:clientId/addresses
    Method.GET / "api" / "clients" / string("clientId") / "addresses" -> handler {
      (clientId: String, request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          pid       <- ZIO
                         .attempt(PersonId(UUID.fromString(clientId)))
                         .mapError(e => new RuntimeException(s"Invalid clientId: $e"))
          _         <- AuthMiddleware.checkRoleOrOwner(user, pid.value, "DISPATCHER", "SECRETARY")
          service   <- ZIO.service[ClientAddressService]
          addresses <- service.getAddresses(pid)
        } yield Response(Status.Ok, body = Body.fromString(addresses.toJson))).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
    },

    // POST /api/clients/:clientId/addresses
    Method.POST / "api" / "clients" / string("clientId") / "addresses" -> handler {
      (clientId: String, request: Request) =>
        (for {
          user    <- AuthMiddleware.authenticateRequest(request)
          pid     <- ZIO
                       .attempt(PersonId(UUID.fromString(clientId)))
                       .mapError(e => new RuntimeException(s"Invalid clientId: $e"))
          _       <- AuthMiddleware.checkRoleOrOwner(user, pid.value, "DISPATCHER", "SECRETARY")
          bodyStr <- request.body.asString
          req     <- ZIO
                       .fromEither(bodyStr.fromJson[SaveClientAddressRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          service <- ZIO.service[ClientAddressService]
          saved   <- service.saveAddress(pid, req)
        } yield Response(Status.Created, body = Body.fromString(saved.toJson))).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
    },

    // DELETE /api/clients/:clientId/addresses/:addressId
    Method.DELETE / "api" / "clients" / string("clientId") / "addresses" / string("addressId") -> handler {
      (clientId: String, addressId: String, request: Request) =>
        (for {
          user    <- AuthMiddleware.authenticateRequest(request)
          pid     <- ZIO
                       .attempt(PersonId(UUID.fromString(clientId)))
                       .mapError(e => new RuntimeException(s"Invalid clientId: $e"))
          _       <- AuthMiddleware.checkRoleOrOwner(user, pid.value, "DISPATCHER", "SECRETARY")
          aid     <- ZIO
                       .attempt(ClientAddressId(UUID.fromString(addressId)))
                       .mapError(e => new RuntimeException(s"Invalid addressId: $e"))
          service <- ZIO.service[ClientAddressService]
          deleted <- service.deleteAddress(aid, pid)
          status   = if deleted then Status.NoContent else Status.NotFound
        } yield Response(status)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
    }
  )
