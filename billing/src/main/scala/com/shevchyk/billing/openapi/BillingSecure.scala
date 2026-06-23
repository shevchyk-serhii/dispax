package com.shevchyk.billing.openapi

import com.shevchyk.auth.domain.{ExpiredTokenError, InvalidTokenError, JwtError}
import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.domain.{InvoiceError, InvoiceId}
import com.shevchyk.core.domain.{ClientCompanyId, CompanyId}
import com.shevchyk.core.openapi.ApiError
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

import java.util.UUID

/**
 * Shared building blocks for the billing-module Tapir endpoints.
 *
 * Declares the authenticated base endpoint once (Bearer security + a `(StatusCode, ApiError)` error channel so the
 * per-error status codes from the old zio-http handlers are preserved) plus the helpers that replicate `AuthMiddleware`
 * / `UuidParser` behaviour while staying inside the `(StatusCode, ApiError)` error channel.
 */
object BillingSecure:

  type Err = (StatusCode, ApiError)

  // -- Authenticated base endpoint (mirrors AuthMiddleware.authenticateRequest) --
  val secureEndpoint = endpoint
    .securityIn(auth.bearer[String]())
    .errorOut(statusCode.and(jsonBody[ApiError]))
    .zServerSecurityLogic[JwtService, AuthenticatedUser] { token =>
      ZIO
        .serviceWithZIO[JwtService](_.validateToken(token))
        .mapBoth(
          {
            case _: InvalidTokenError | _: ExpiredTokenError =>
              (StatusCode.Unauthorized, ApiError("Invalid or expired token"))
            case _: JwtError                                 => (StatusCode.Unauthorized, ApiError("Authentication failed"))
          },
          payload =>
            AuthenticatedUser(
              userId = payload.userId,
              email = payload.email,
              role = payload.role.toString,
              companyId = payload.companyId,
              clientCompanyId = payload.clientCompanyId
            )
        )
    }

  // -- Role checks (mirror AuthMiddleware.checkRole) -----------------------

  def checkRole(user: AuthenticatedUser, roles: String*): ZIO[Any, Err, Unit] =
    val userRoleUpper = user.role.toUpperCase
    if roles.exists(_.toUpperCase == userRoleUpper) then ZIO.unit
    else ZIO.fail((StatusCode.Forbidden, ApiError("Insufficient permissions")))

  // -- UUID parsing (mirrors UuidParser, which fails with 400) -------------

  def parseUuid(value: String): ZIO[Any, Err, UUID] = ZIO
    .attempt(UUID.fromString(value))
    .orElseFail((StatusCode.BadRequest, ApiError("Invalid UUID format")))

  def parseInvoiceId(value: String): ZIO[Any, Err, InvoiceId] = parseUuid(value).map(InvoiceId(_))

  def parseClientCompanyId(value: String): ZIO[Any, Err, ClientCompanyId] = parseUuid(value).map(ClientCompanyId(_))

  def requireCompanyId(companyIdOpt: Option[UUID]): ZIO[Any, Err, CompanyId] = ZIO
    .fromOption(companyIdOpt)
    .map(CompanyId(_))
    .orElseFail((StatusCode.BadRequest, ApiError("User must belong to a company")))

  /**
   * Map an `InvoiceError` to the same status/body as `InvoiceRoutes.handleError`.
   */
  def fromInvoiceError(ex: InvoiceError): Err =
    ex match
      case InvoiceError.NotFound(_)              => (StatusCode.NotFound, ApiError("Invoice not found"))
      case InvoiceError.ClientCompanyNotFound(_) => (StatusCode.NotFound, ApiError("Client company not found"))
      case InvoiceError.NotDraft(_)              => (StatusCode.Conflict, ApiError("Invoice must be in draft status"))
      case InvoiceError.InvalidStatus(cur, req)  =>
        (StatusCode.Conflict, ApiError(s"Invalid status: ${cur}, required: $req"))
      case InvoiceError.RideNotBillable(rideId)  =>
        (StatusCode.BadRequest, ApiError(s"Ride $rideId cannot be billed on this invoice"))
      case InvoiceError.NoRecipientEmail(_)      => (StatusCode.BadRequest, ApiError("Client company has no email address"))
      case InvoiceError.InvalidTaxRate(rate)     =>
        (StatusCode.BadRequest, ApiError(s"Invalid tax rate: $rate (must be between 0 and 100)"))
      case InvoiceError.DatabaseError(_)         => (StatusCode.InternalServerError, ApiError("Internal server error"))
      case InvoiceError.PdfGenerationError(_)    => (StatusCode.InternalServerError, ApiError("PDF generation failed"))
      case InvoiceError.EmailDeliveryError(_)    =>
        (StatusCode.BadGateway, ApiError("Email delivery failed; invoice not sent"))

  /**
   * Generic throwable mapping (mirrors the `Throwable` catch-all → 500).
   */
  def internalError: Err = (StatusCode.InternalServerError, ApiError("Internal server error"))
