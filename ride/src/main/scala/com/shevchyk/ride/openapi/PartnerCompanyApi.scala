package com.shevchyk.ride.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.CreatePartnerCompanyRequest
import com.shevchyk.ride.infrastructure.http.dto.{CreatePartnerCompanyApiRequest, PartnerCompanyDto, given}
import com.shevchyk.ride.openapi.RideSchemas.given
import com.shevchyk.ride.openapi.RideSecure.*
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import java.time.Instant

/**
 * Tapir descriptions and server logic for the partner-company directory endpoints. Per-tenant: all queries and
 * mutations are scoped to the caller's `CompanyId` from the JWT.
 */
object PartnerCompanyApi:

  private val tag = "Partner Companies"

  type PartnerCompanyEnv = RideService & JwtService

  val listPartnerCompaniesEndpoint = secureEndpoint.get
    .in("api" / "partner-companies")
    .out(jsonBody[List[PartnerCompanyDto]])
    .tag(tag)
    .summary("List partner companies for the caller's tenant")

  val createPartnerCompanyEndpoint = secureEndpoint.post
    .in("api" / "partner-companies")
    .in(jsonBody[CreatePartnerCompanyApiRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[PartnerCompanyDto]))
    .tag(tag)
    .summary("Create a partner company")

  val endpoints = List(listPartnerCompaniesEndpoint, createPartnerCompanyEndpoint)

  private def toDto(pc: com.shevchyk.ride.domain.PartnerCompany): PartnerCompanyDto = PartnerCompanyDto(
    id = pc.id.value.toString,
    name = pc.name,
    email = pc.email,
    phone = pc.phone,
    address = pc.address,
    taxiCompanyId = pc.taxiCompanyId.value.toString,
    createdAt = pc.createdAt.toString,
    updatedAt = pc.updatedAt.toString
  )

  private val listPartnerCompaniesServer: ZServerEndpoint[PartnerCompanyEnv, Any] = listPartnerCompaniesEndpoint
    .serverLogic { user => _ =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        service   <- ZIO.service[RideService]
        companies <- service.listPartnerCompanies(companyId).mapError(fromRideError)
      } yield companies.map(toDto)
    }

  private val createPartnerCompanyServer: ZServerEndpoint[PartnerCompanyEnv, Any] = createPartnerCompanyEndpoint
    .serverLogic { user => req =>
      for {
        _         <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId <- requireCompanyId(user.companyId)
        service   <- ZIO.service[RideService]
        created   <- service
                       .createPartnerCompany(
                         companyId,
                         CreatePartnerCompanyRequest(
                           name = req.name,
                           email = req.email,
                           phone = req.phone,
                           address = req.address
                         )
                       )
                       .mapError(fromRideError)
      } yield toDto(created)
    }

  val serverEndpoints: List[ZServerEndpoint[PartnerCompanyEnv, Any]] = List(
    listPartnerCompaniesServer,
    createPartnerCompanyServer
  )
