package com.shevchyk.schedule.openapi

import com.shevchyk.auth.domain.{ExpiredTokenError, InvalidTokenError, JwtError}
import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CalendarShareGrantId, CalendarShareInviteId, CompanyId, PersonId, PersonRole}
import com.shevchyk.core.openapi.{ApiError, ErrorMapper}
import com.shevchyk.schedule.application.CalendarShareService
import com.shevchyk.schedule.domain.CalendarShareError
import com.shevchyk.schedule.infrastructure.http.dto.*
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

import java.time.LocalDate
import java.util.UUID

/**
 * Cross-company personal calendar sharing. A driver/dispatcher mints an opaque invite code; a user of another (or the
 * same) company redeems it while logged in, and the resulting grant authorizes a PII-free read of the grantor's
 * personal calendar (shifts + busy slots) — no re-login, the grantee's own JWT plus the grant row is the whole
 * authorization. Identity is taken exclusively from the JWT; no person id is ever read from a request body.
 */
object CalendarShareApi:

  private val shareTag = "Calendar sharing"

  type CalendarShareEnv = CalendarShareService & JwtService

  private def toError(ex: Throwable): (StatusCode, ApiError) = ErrorMapper.fromThrowable[CalendarShareError](ex)

  // Mirrors ScheduleApi.secureEndpoint (bearer → AuthenticatedUser with per-error status codes).
  private val secureEndpoint = endpoint
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
        )
    }

  /**
   * Calendar sharing is a staff feature: drivers, dispatchers and admins only. Clients/secretaries get a 403.
   */
  private[openapi] def requireStaffRole(user: AuthenticatedUser): ZIO[Any, (StatusCode, ApiError), Unit] =
    ZIO
      .fail((StatusCode.Forbidden, ApiError("Insufficient permissions")))
      .unless(user.hasAnyRole("DRIVER", "DISPATCHER", "ADMIN"))
      .unit

  private def requireCompanyId(user: AuthenticatedUser): ZIO[Any, CalendarShareError, CompanyId] = ZIO
    .fromOption(user.companyId)
    .map(CompanyId(_))
    .orElseFail(CalendarShareError.ValidationError("User must belong to a company"))

  private def parseGrantId(raw: String): ZIO[Any, CalendarShareError, CalendarShareGrantId] = ZIO
    .attempt(CalendarShareGrantId(UUID.fromString(raw)))
    .orElseFail(CalendarShareError.ValidationError("Invalid UUID format"))

  private def parseDate(raw: String, param: String): ZIO[Any, CalendarShareError, LocalDate] = ZIO
    .attempt(LocalDate.parse(raw))
    .orElseFail(CalendarShareError.ValidationError(s"Invalid '$param' date format: $raw"))

  // -- Endpoint descriptions -------------------------------------------------

  val createInviteEndpoint = secureEndpoint.post
    .in("api" / "calendar-shares" / "invites")
    .in(jsonBody[CreateCalendarShareInviteApiRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[CalendarShareInviteDto]))
    .tag(shareTag)
    .summary("Mint an invite code for the caller's personal calendar (driver, dispatcher, admin)")

  val listInvitesEndpoint = secureEndpoint.get
    .in("api" / "calendar-shares" / "invites")
    .out(jsonBody[List[CalendarShareInviteDto]])
    .tag(shareTag)
    .summary("List the caller's active invites")

  val revokeInviteEndpoint = secureEndpoint.delete
    .in("api" / "calendar-shares" / "invites" / path[String]("inviteId"))
    .out(statusCode(StatusCode.NoContent))
    .tag(shareTag)
    .summary("Revoke one of the caller's invites")

  val redeemEndpoint = secureEndpoint.post
    .in("api" / "calendar-shares" / "redeem")
    .in(jsonBody[RedeemCalendarShareApiRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[CalendarShareGrantDto]))
    .tag(shareTag)
    .summary("Redeem an invite code as the calling user (idempotent for an already-connected pair)")

  val listGrantedEndpoint = secureEndpoint.get
    .in("api" / "calendar-shares" / "granted")
    .out(jsonBody[List[CalendarShareGrantDto]])
    .tag(shareTag)
    .summary("List active grants where the caller is the grantor")

  val revokeGrantedEndpoint = secureEndpoint.delete
    .in("api" / "calendar-shares" / "granted" / path[String]("grantId"))
    .out(statusCode(StatusCode.NoContent))
    .tag(shareTag)
    .summary("Revoke a grant the caller issued")

  val listSharedWithMeEndpoint = secureEndpoint.get
    .in("api" / "calendar-shares" / "shared-with-me")
    .out(jsonBody[List[CalendarShareGrantDto]])
    .tag(shareTag)
    .summary("List active grants where the caller is the grantee")

  val unlinkSharedWithMeEndpoint = secureEndpoint.delete
    .in("api" / "calendar-shares" / "shared-with-me" / path[String]("grantId"))
    .out(statusCode(StatusCode.NoContent))
    .tag(shareTag)
    .summary("Unlink a calendar that was shared with the caller (revokes the grant)")

  val getSharedCalendarEndpoint = secureEndpoint.get
    .in("api" / "calendar-shares" / path[String]("grantId") / "calendar")
    .in(query[Option[String]]("from"))
    .in(query[Option[String]]("to"))
    .out(jsonBody[SharedCalendarDto])
    .tag(shareTag)
    .summary("Read the shared calendar (grantee only; PII-free shifts + busy slots; no live updates — poll)")

  val endpoints = List(
    createInviteEndpoint,
    listInvitesEndpoint,
    revokeInviteEndpoint,
    redeemEndpoint,
    listGrantedEndpoint,
    revokeGrantedEndpoint,
    listSharedWithMeEndpoint,
    unlinkSharedWithMeEndpoint,
    getSharedCalendarEndpoint
  )

  // -- Server logic ------------------------------------------------------------

  private val createInviteServer: ZServerEndpoint[CalendarShareEnv, Any] = createInviteEndpoint.serverLogic {
    user => request =>
      requireStaffRole(user) *> (for {
        companyId <- requireCompanyId(user)
        service   <- ZIO.service[CalendarShareService]
        invite    <- service.createInvite(PersonId(user.userId), companyId, request.expiresInDays)
      } yield CalendarShareInviteDto.fromDomain(invite)).mapError(toError)
  }

  private val listInvitesServer: ZServerEndpoint[CalendarShareEnv, Any] = listInvitesEndpoint.serverLogic { user => _ =>
    requireStaffRole(user) *> (for {
      service <- ZIO.service[CalendarShareService]
      invites <- service.listMyInvites(PersonId(user.userId))
    } yield invites.map(CalendarShareInviteDto.fromDomain)).mapError(toError)
  }

  private val revokeInviteServer: ZServerEndpoint[CalendarShareEnv, Any] = revokeInviteEndpoint.serverLogic {
    user => inviteIdStr =>
      requireStaffRole(user) *> (for {
        inviteId <- ZIO
                      .attempt(CalendarShareInviteId(UUID.fromString(inviteIdStr)))
                      .orElseFail(CalendarShareError.ValidationError("Invalid UUID format"))
        service  <- ZIO.service[CalendarShareService]
        _        <- service.revokeInvite(inviteId, PersonId(user.userId))
      } yield ()).mapError(toError)
  }

  private val redeemServer: ZServerEndpoint[CalendarShareEnv, Any] = redeemEndpoint.serverLogic { user => request =>
    requireStaffRole(user) *> (for {
      companyId <- requireCompanyId(user)
      service   <- ZIO.service[CalendarShareService]
      view      <- service.redeem(request.code, PersonId(user.userId), companyId)
    } yield CalendarShareGrantDto.fromView(view)).mapError(toError)
  }

  private val listGrantedServer: ZServerEndpoint[CalendarShareEnv, Any] = listGrantedEndpoint.serverLogic { user => _ =>
    requireStaffRole(user) *> (for {
      service <- ZIO.service[CalendarShareService]
      views   <- service.listGranted(PersonId(user.userId))
    } yield views.map(CalendarShareGrantDto.fromView)).mapError(toError)
  }

  private val revokeGrantedServer: ZServerEndpoint[CalendarShareEnv, Any] = revokeGrantedEndpoint.serverLogic {
    user => grantIdStr =>
      requireStaffRole(user) *> (for {
        grantId <- parseGrantId(grantIdStr)
        service <- ZIO.service[CalendarShareService]
        _       <- service.revokeGrant(grantId, PersonId(user.userId))
      } yield ()).mapError(toError)
  }

  private val listSharedWithMeServer: ZServerEndpoint[CalendarShareEnv, Any] = listSharedWithMeEndpoint.serverLogic {
    user => _ =>
      requireStaffRole(user) *> (for {
        service <- ZIO.service[CalendarShareService]
        views   <- service.listSharedWithMe(PersonId(user.userId))
      } yield views.map(CalendarShareGrantDto.fromView)).mapError(toError)
  }

  private val unlinkSharedWithMeServer: ZServerEndpoint[CalendarShareEnv, Any] = unlinkSharedWithMeEndpoint
    .serverLogic { user => grantIdStr =>
      requireStaffRole(user) *> (for {
        grantId <- parseGrantId(grantIdStr)
        service <- ZIO.service[CalendarShareService]
        _       <- service.revokeGrant(grantId, PersonId(user.userId))
      } yield ()).mapError(toError)
    }

  private val getSharedCalendarServer: ZServerEndpoint[CalendarShareEnv, Any] = getSharedCalendarEndpoint.serverLogic {
    user => (grantIdStr, fromOpt, toOpt) =>
      requireStaffRole(user) *> (for {
        grantId   <- parseGrantId(grantIdStr)
        fromParam <- ZIO
                       .fromOption(fromOpt)
                       .orElseFail(CalendarShareError.ValidationError("Query parameter 'from' is required"))
        toParam   <- ZIO
                       .fromOption(toOpt)
                       .orElseFail(CalendarShareError.ValidationError("Query parameter 'to' is required"))
        from      <- parseDate(fromParam, "from")
        to        <- parseDate(toParam, "to")
        service   <- ZIO.service[CalendarShareService]
        calendar  <- service.getSharedCalendar(grantId, PersonId(user.userId), from, to)
      } yield SharedCalendarDto.fromDomain(calendar)).mapError(toError)
  }

  /**
   * NOTE: all static-prefix endpoints (`invites`, `redeem`, `granted`, `shared-with-me`) must precede
   * `getSharedCalendarServer` (dynamic "/{grantId}/calendar") so the static segments are not swallowed by the id
   * pattern — same convention as ScheduleApi.
   */
  val serverEndpoints: List[ZServerEndpoint[CalendarShareEnv, Any]] = List(
    createInviteServer,
    listInvitesServer,
    revokeInviteServer,
    redeemServer,
    listGrantedServer,
    revokeGrantedServer,
    listSharedWithMeServer,
    unlinkSharedWithMeServer,
    getSharedCalendarServer
  )
