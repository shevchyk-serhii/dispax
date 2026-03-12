package com.shevchyk.auth.middleware

import com.shevchyk.core.domain.{CompanyId, PersonId, RideId}
import zio.*
import zio.http.*
import java.util.UUID

object UuidParser:

  private val badUuidResponse: Response = Response(
    Status.BadRequest,
    body = Body.fromString("""{"error":"Invalid UUID format"}""")
  )

  def parse(value: String): IO[Response, UUID] = ZIO.attempt(UUID.fromString(value)).mapError(_ => badUuidResponse)

  def parsePersonId(value: String): IO[Response, PersonId] = parse(value).map(PersonId(_))

  def parseRideId(value: String): IO[Response, RideId] = parse(value).map(RideId(_))

  def parseCompanyId(value: String): IO[Response, CompanyId] = parse(value).map(CompanyId(_))

  /**
   * Extract companyId from authenticated user, failing with 400 if missing
   */
  def requireCompanyId(companyIdOpt: Option[UUID]): IO[Response, CompanyId] = ZIO
    .fromOption(companyIdOpt)
    .map(CompanyId(_))
    .orElseFail(Response(Status.BadRequest, body = Body.fromString("""{"error":"User must belong to a company"}""")))
