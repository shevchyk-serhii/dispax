package com.shevchyk.ride.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.PersonId
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.ride.application.service.ClientAddressService
import com.shevchyk.ride.domain.{ClientAddress, ClientAddressId, SaveClientAddressRequest, UpdateClientAddressRequest}
import com.shevchyk.ride.openapi.RideSchemas.given
import com.shevchyk.ride.openapi.RideSecure.*
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Tapir descriptions and server logic for the client-address endpoints. Replaces the zio-http handlers in
 * `ClientAddressRoutes`, keeping the exact paths, status codes, role checks and company isolation. Invalid ids /
 * invalid JSON map to a 500, matching the original handler.
 */
object ClientAddressApi:

  private val addressTag = "Client addresses"

  type ClientAddressEnv = ClientAddressService & JwtService

  private def internalError: Err = (StatusCode.InternalServerError, ApiError("Internal server error"))

  private def parseClientPid(value: String): ZIO[Any, Err, PersonId] =
    ZIO.attempt(PersonId(java.util.UUID.fromString(value))).mapError(_ => internalError)

  private def parseAddressId(value: String): ZIO[Any, Err, ClientAddressId] =
    ZIO.attempt(ClientAddressId(java.util.UUID.fromString(value))).mapError(_ => internalError)

  // -- Endpoint descriptions -----------------------------------------------

  val getAddressesEndpoint =
    secureEndpoint.get
      .in("api" / "clients" / path[String]("clientId") / "addresses")
      .out(jsonBody[List[ClientAddress]])
      .tag(addressTag)
      .summary("List a client's saved addresses")

  val saveAddressEndpoint =
    secureEndpoint.post
      .in("api" / "clients" / path[String]("clientId") / "addresses")
      .in(jsonBody[SaveClientAddressRequest])
      .out(statusCode(StatusCode.Created).and(jsonBody[ClientAddress]))
      .tag(addressTag)
      .summary("Save a client address")

  val updateAddressEndpoint =
    secureEndpoint.patch
      .in("api" / "clients" / path[String]("clientId") / "addresses" / path[String]("addressId"))
      .in(jsonBody[UpdateClientAddressRequest])
      .out(jsonBody[ClientAddress])
      .tag(addressTag)
      .summary("Update a client address")

  val deleteAddressEndpoint =
    secureEndpoint.delete
      .in("api" / "clients" / path[String]("clientId") / "addresses" / path[String]("addressId"))
      .out(statusCode(StatusCode.NoContent))
      .tag(addressTag)
      .summary("Delete a client address")

  val endpoints = List(getAddressesEndpoint, saveAddressEndpoint, updateAddressEndpoint, deleteAddressEndpoint)

  // -- Server logic --------------------------------------------------------

  private val getAddressesServer: ZServerEndpoint[ClientAddressEnv, Any] =
    getAddressesEndpoint.serverLogic { user => clientId =>
      (for {
        pid       <- parseClientPid(clientId)
        _         <- checkRoleOrOwner(user, pid.value, "DISPATCHER", "SECRETARY", "DRIVER")
        service   <- ZIO.service[ClientAddressService]
        addresses <- service.getAddresses(pid).mapError(_ => internalError)
      } yield addresses)
    }

  private val saveAddressServer: ZServerEndpoint[ClientAddressEnv, Any] =
    saveAddressEndpoint.serverLogic { user => (clientId, req) =>
      (for {
        pid     <- parseClientPid(clientId)
        _       <- checkRoleOrOwner(user, pid.value, "DISPATCHER", "SECRETARY")
        service <- ZIO.service[ClientAddressService]
        saved   <- service.saveAddress(pid, req).mapError(_ => internalError)
      } yield saved)
    }

  private val updateAddressServer: ZServerEndpoint[ClientAddressEnv, Any] =
    updateAddressEndpoint.serverLogic { user => (clientId, addressId, req) =>
      (for {
        pid     <- parseClientPid(clientId)
        _       <- checkRoleOrOwner(user, pid.value, "DISPATCHER", "SECRETARY")
        aid     <- parseAddressId(addressId)
        service <- ZIO.service[ClientAddressService]
        result  <- service.updateAddress(aid, pid, req).mapError(_ => internalError)
        addr    <- ZIO
                     .fromOption(result)
                     .orElseFail((StatusCode.NotFound, ApiError("Address not found")))
      } yield addr)
    }

  private val deleteAddressServer: ZServerEndpoint[ClientAddressEnv, Any] =
    deleteAddressEndpoint.serverLogic { user => (clientId, addressId) =>
      (for {
        pid     <- parseClientPid(clientId)
        _       <- checkRoleOrOwner(user, pid.value, "DISPATCHER", "SECRETARY")
        aid     <- parseAddressId(addressId)
        service <- ZIO.service[ClientAddressService]
        deleted <- service.deleteAddress(aid, pid).mapError(_ => internalError)
        _       <- ZIO.fail((StatusCode.NotFound, ApiError("Not found"))).when(!deleted)
      } yield ())
    }

  val serverEndpoints: List[ZServerEndpoint[ClientAddressEnv, Any]] =
    List(getAddressesServer, saveAddressServer, updateAddressServer, deleteAddressServer)
