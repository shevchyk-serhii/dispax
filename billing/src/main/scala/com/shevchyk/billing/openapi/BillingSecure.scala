package com.shevchyk.billing.openapi

import com.shevchyk.auth.domain.{ExpiredTokenError, InvalidTokenError, JwtError}
import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.auth.service.{JwtPayload, JwtService}
import com.shevchyk.billing.domain.{InvoiceError, InvoiceId}
import com.shevchyk.core.domain.{ClientCompanyId, CompanyId, PersonRole}
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

  /**
   * Paging guards for billing list endpoints: a hostile/huge `limit` must not dump the whole table and a negative
   * `offset` must not error out Postgres. Mirrors the inline clamps in NotificationApi/AuditApi.
   */
  object Paging:
    val DefaultLimit                  = 50
    val MaxLimit                      = 100
    def clampLimit(limit: Int): Int   = limit.min(MaxLimit).max(1)
    def clampOffset(offset: Int): Int = offset.max(0)

  /**
   * Map a validated JWT payload to the request's [[AuthenticatedUser]]. Roles are normalised to wire form via
   * `PersonRole.toWire` and the FULL roles set is carried over (multi-role users such as a dispatcher who also drives),
   * mirroring `RideSecure`/`AppSecure`. Package-private for unit testing.
   */
  private[openapi] def toAuthenticatedUser(payload: JwtPayload): AuthenticatedUser =
    val wireRoles = payload.roles
      .map(_.map(PersonRole.toWire).toSet)
      .getOrElse(Set(PersonRole.toWire(payload.role)))
    AuthenticatedUser(
      userId = payload.userId,
      email = payload.email,
      role = PersonRole.toWire(payload.role),
      companyId = payload.companyId,
      clientCompanyId = payload.clientCompanyId,
      roles = wireRoles
    )

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
          toAuthenticatedUser
        )
    }

  // -- Role checks (mirror AuthMiddleware.checkRole) -----------------------

  def checkRole(user: AuthenticatedUser, roles: String*): ZIO[Any, Err, Unit] =
    // Check the FULL effective role set, not just the primary role — a multi-role user (e.g. primary DRIVER with
    // DISPATCHER in the set) must pass a dispatcher-gated billing endpoint, same as RideSecure/AppSecure.
    if user.hasAnyRole(roles*) then ZIO.unit
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
      case InvoiceError.EmptyInvoice(_)          => (StatusCode.Conflict, ApiError("Invoice has no line items"))
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
