package com.shevchyk.ride.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.PartnerCompanyId
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.CreateExternalDriverRequest
import com.shevchyk.ride.infrastructure.http.dto.{CreateExternalDriverApiRequest, ExternalDriverDto, given}
import com.shevchyk.ride.openapi.RideSecure.*
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import java.util.UUID

/**
 * Tapir descriptions and server logic for the external-driver directory endpoints. Per-tenant: all queries and
 * mutations are scoped to the caller's `CompanyId` from the JWT.
 */
object ExternalDriverApi:

  private val tag = "External Drivers"

  type ExternalDriverEnv = RideService & JwtService

  val listExternalDriversEndpoint = secureEndpoint.get
    .in("api" / "external-drivers")
    .out(jsonBody[List[ExternalDriverDto]])
    .tag(tag)
    .summary("List external drivers for the caller's tenant")

  val createExternalDriverEndpoint = secureEndpoint.post
    .in("api" / "external-drivers")
    .in(jsonBody[CreateExternalDriverApiRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[ExternalDriverDto]))
    .tag(tag)
    .summary("Create an external driver")

  val endpoints = List(listExternalDriversEndpoint, createExternalDriverEndpoint)

  private def toDto(ed: com.shevchyk.ride.domain.ExternalDriver): ExternalDriverDto = ExternalDriverDto(
    id = ed.id.value.toString,
    name = ed.name,
    phone = ed.phone,
    partnerCompanyId = ed.partnerCompanyId.map(_.value.toString),
    taxiCompanyId = ed.taxiCompanyId.value.toString,
    createdAt = ed.createdAt.toString,
    updatedAt = ed.updatedAt.toString
  )

  private val listExternalDriversServer: ZServerEndpoint[ExternalDriverEnv, Any] = listExternalDriversEndpoint
    .serverLogic { user => _ =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        service   <- ZIO.service[RideService]
        drivers   <- service.listExternalDrivers(companyId).mapError(fromRideError)
      } yield drivers.map(toDto)
    }

  private val createExternalDriverServer: ZServerEndpoint[ExternalDriverEnv, Any] = createExternalDriverEndpoint
    .serverLogic { user => req =>
      for {
        _                <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId        <- requireCompanyId(user.companyId)
        partnerCompanyId <-
          req.partnerCompanyId match
            case Some(s) =>
              ZIO
                .attempt(UUID.fromString(s))
                .mapError(_ => (sttp.model.StatusCode.BadRequest, ApiError("Invalid partnerCompanyId UUID")))
                .map(id => Some(PartnerCompanyId(id)))
            case None    => ZIO.none
        service          <- ZIO.service[RideService]
        created          <- service
                              .createExternalDriver(
                                companyId,
                                CreateExternalDriverRequest(
                                  name = req.name,
                                  phone = req.phone,
                                  partnerCompanyId = partnerCompanyId
                                )
                              )
                              .mapError(fromRideError)
      } yield toDto(created)
    }

  val serverEndpoints: List[ZServerEndpoint[ExternalDriverEnv, Any]] = List(
    listExternalDriversServer,
    createExternalDriverServer
  )
