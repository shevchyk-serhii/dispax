package com.shevchyk.schedule.openapi

import com.shevchyk.auth.domain.{ExpiredTokenError, InvalidTokenError, JwtError}
import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, DriverUnavailabilityId, PersonId, ScheduleDayId}
import com.shevchyk.core.openapi.{ApiError, ErrorMapper}
import com.shevchyk.schedule.application.ScheduleService
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.infrastructure.http.dto.{*, given}
import com.shevchyk.schedule.validation.given
import com.shevchyk.schedule.validation.Validator.validate
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

import java.time.{Instant, LocalDate}
import java.util.UUID

/**
 * Tapir descriptions and server logic for the schedule endpoints. These replace the hand-written zio-http handlers in
 * `ScheduleRoutes` while keeping the exact same paths, request/response shapes, status codes and company isolation. The
 * same `ServerEndpoint`s drive both the OpenAPI document and the running server.
 */
object ScheduleApi:

  private val scheduleTag = "Schedules"

  // -- Environment ---------------------------------------------------------
  type ScheduleEnv = ScheduleService & JwtService

  // -- Error mapping (mirrors ScheduleRoutes.handleScheduleError) -----------

  // Delegates to the `ErrorMapper[ScheduleError]` defined alongside the domain;
  // unexpected throwables collapse to a generic 500.
  private def toError(ex: Throwable): (StatusCode, ApiError) = ErrorMapper.fromThrowable[ScheduleError](ex)

  // -- Authenticated base endpoint -----------------------------------------
  //
  // Like `auth.secureEndpoint`, but with a `(StatusCode, ApiError)`
  // error channel so the per-error status codes from `handleScheduleError` are
  // preserved (400/403/404/409/500). The JWT validation matches AuthMiddleware.
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
            case _                                           => (StatusCode.InternalServerError, ApiError("Internal server error"))
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

  private def requireCompanyId(user: AuthenticatedUser): ZIO[Any, ScheduleError, CompanyId] = ZIO
    .fromOption(user.companyId)
    .map(CompanyId(_))
    .orElseFail(ScheduleError.ValidationError("User must belong to a company"))

  /**
   * Reject roles that are neither Dispatcher nor Admin. Maps to a 403 Forbidden.
   */
  private def requireDispatcherOrAdmin(
      user: AuthenticatedUser
  ): ZIO[Any, (StatusCode, ApiError), Unit] =
    val role = user.role.toUpperCase
    ZIO
      .fail((StatusCode.Forbidden, ApiError("Insufficient permissions")))
      .unless(role == "DISPATCHER" || role == "ADMIN")
      .unit

  // -- Endpoint descriptions -----------------------------------------------

  val createScheduleDayEndpoint = secureEndpoint.post
    .in("api" / "schedules")
    .in(jsonBody[CreateScheduleDayApiRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[ScheduleDayDto]))
    .tag(scheduleTag)
    .summary("Create a single schedule day")

  val createScheduleBatchEndpoint = secureEndpoint.post
    .in("api" / "schedules" / "batch")
    .in(jsonBody[CreateScheduleBatchApiRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[List[ScheduleDayDto]]))
    .tag(scheduleTag)
    .summary("Create multiple schedule days")

  val getDriverScheduleEndpoint = secureEndpoint.get
    .in("api" / "schedules" / "driver" / path[String]("driverId"))
    .out(jsonBody[List[ScheduleDayDto]])
    .tag(scheduleTag)
    .summary("Get a driver's schedule (access-controlled for drivers)")

  val getScheduleForDateEndpoint = secureEndpoint.get
    .in("api" / "schedules" / "day" / path[String]("date"))
    .out(jsonBody[List[ScheduleDayDto]])
    .tag(scheduleTag)
    .summary("Get all schedules for a date")

  val getScheduleRangeEndpoint = secureEndpoint.get
    .in("api" / "schedules")
    .in(query[Option[String]]("from"))
    .in(query[Option[String]]("to"))
    .out(jsonBody[List[ScheduleDayDto]])
    .tag(scheduleTag)
    .summary("Get schedules for a date range")

  val updateScheduleDayEndpoint = secureEndpoint.put
    .in("api" / "schedules" / path[String]("id"))
    .in(jsonBody[UpdateScheduleDayApiRequest])
    .out(jsonBody[ScheduleDayDto])
    .tag(scheduleTag)
    .summary("Update a schedule day")

  val deleteScheduleDayEndpoint = secureEndpoint.delete
    .in("api" / "schedules" / path[String]("id"))
    .out(jsonBody[ScheduleDayDto])
    .tag(scheduleTag)
    .summary("Cancel a schedule day")

  // -- Visibility endpoints (Dispatcher/Admin only) ------------------------

  val getCompanyVisibilityEndpoint = secureEndpoint.get
    .in("api" / "schedules" / "visibility")
    .out(jsonBody[List[DriverScheduleVisibilityDto]])
    .tag(scheduleTag)
    .summary("List per-driver schedule-visibility settings for the company (dispatcher, admin)")

  val getMyVisibilityEndpoint = secureEndpoint.get
    .in("api" / "schedules" / "visibility" / "me")
    .out(jsonBody[DriverScheduleVisibilityDto])
    .tag(scheduleTag)
    .summary("Get the caller's own schedule-visibility flag (any authenticated user)")

  val setDriverVisibilityEndpoint = secureEndpoint.put
    .in("api" / "schedules" / "visibility" / path[String]("driverId"))
    .in(jsonBody[SetDriverVisibilityRequest])
    .out(jsonBody[DriverScheduleVisibilityDto])
    .tag(scheduleTag)
    .summary("Set whether a driver may view other drivers' full schedules (dispatcher, admin)")

  // -- Unavailability endpoints -------------------------------------------
  // NOTE: static "unavailability/..." paths must be registered before any
  // "/{id}" pattern to avoid the static prefix being swallowed by the id segment.

  val createUnavailabilityEndpoint = secureEndpoint.post
    .in("api" / "schedules" / "unavailability")
    .in(jsonBody[CreateDriverUnavailabilityApiRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[DriverUnavailabilityDto]))
    .tag(scheduleTag)
    .summary("Mark a driver unavailability window (driver-only-self)")

  val getDriverUnavailabilityEndpoint = secureEndpoint.get
    .in("api" / "schedules" / "unavailability" / "driver" / path[String]("driverId"))
    .out(jsonBody[List[DriverUnavailabilityDto]])
    .tag(scheduleTag)
    .summary("Get unavailability windows for a driver (access-controlled)")

  val getCompanyUnavailabilityEndpoint = secureEndpoint.get
    .in("api" / "schedules" / "unavailability")
    .in(query[Option[String]]("from"))
    .in(query[Option[String]]("to"))
    .out(jsonBody[List[DriverUnavailabilityDto]])
    .tag(scheduleTag)
    .summary("Get all unavailability windows for the company in a time range")

  val deleteUnavailabilityEndpoint = secureEndpoint.delete
    .in("api" / "schedules" / "unavailability" / path[String]("id"))
    .out(statusCode(StatusCode.NoContent))
    .tag(scheduleTag)
    .summary("Delete a driver unavailability window (owner, dispatcher, or admin)")

  /**
   * All endpoint descriptions, used to generate the OpenAPI document.
   */
  val endpoints = List(
    createScheduleDayEndpoint,
    createScheduleBatchEndpoint,
    getDriverScheduleEndpoint,
    getScheduleForDateEndpoint,
    getScheduleRangeEndpoint,
    updateScheduleDayEndpoint,
    deleteScheduleDayEndpoint,
    getCompanyVisibilityEndpoint,
    getMyVisibilityEndpoint,
    setDriverVisibilityEndpoint,
    createUnavailabilityEndpoint,
    getDriverUnavailabilityEndpoint,
    getCompanyUnavailabilityEndpoint,
    deleteUnavailabilityEndpoint
  )

  // -- Server logic --------------------------------------------------------

  private val createScheduleDayServer: ZServerEndpoint[ScheduleEnv, Any] = createScheduleDayEndpoint.serverLogic {
    user => apiRequest =>
      (for {
        companyId     <- requireCompanyId(user)
        validRequest  <- apiRequest.validate
        domainRequest <- CreateScheduleDayApiRequest.toDomain(validRequest, companyId)
        service       <- ZIO.service[ScheduleService]
        scheduleDay   <- service.createScheduleDay(domainRequest)
      } yield ScheduleDayDto.fromDomain(scheduleDay)).mapError(toError)
  }

  private val createScheduleBatchServer: ZServerEndpoint[ScheduleEnv, Any] = createScheduleBatchEndpoint.serverLogic {
    user => apiRequest =>
      (for {
        companyId     <- requireCompanyId(user)
        validRequest  <- apiRequest.validate
        domainRequest <- CreateScheduleBatchApiRequest.toDomain(validRequest, companyId)
        service       <- ZIO.service[ScheduleService]
        days          <- service.createBatch(domainRequest)
      } yield days.map(ScheduleDayDto.fromDomain)).mapError(toError)
  }

  /**
   * GET /api/schedules/driver/:driverId
   *
   * Access control (closes the pre-existing security hole):
   *   - requester == target driver → always OK
   *   - Dispatcher / Admin / Secretary → always OK
   *   - Driver requesting a different driver's schedule → only if the requesting driver has `canViewOtherSchedules =
   *     true`; otherwise 403.
   */
  private val getDriverScheduleServer: ZServerEndpoint[ScheduleEnv, Any] = getDriverScheduleEndpoint.serverLogic {
    user => driverId =>
      (for {
        companyId  <- requireCompanyId(user)
        driverPid  <- ZIO
                        .attempt(PersonId(UUID.fromString(driverId)))
                        .orElseFail(ScheduleError.ValidationError("Invalid UUID format"))
        requesterId = PersonId(user.userId)
        service    <- ZIO.service[ScheduleService]
        days       <- service.getDriverScheduleAs(requesterId, user.role, driverPid, companyId)
      } yield days.map(ScheduleDayDto.fromDomain)).mapError(toError)
  }

  private val getScheduleForDateServer: ZServerEndpoint[ScheduleEnv, Any] = getScheduleForDateEndpoint.serverLogic {
    user => date =>
      (for {
        companyId <- requireCompanyId(user)
        localDate <- ZIO
                       .attempt(LocalDate.parse(date))
                       .orElseFail(ScheduleError.ValidationError(s"Invalid date format: $date"))
        service   <- ZIO.service[ScheduleService]
        days      <- service.getScheduleForDate(companyId, localDate)
      } yield days.map(ScheduleDayDto.fromDomain)).mapError(toError)
  }

  private val getScheduleRangeServer: ZServerEndpoint[ScheduleEnv, Any] = getScheduleRangeEndpoint.serverLogic {
    user => (fromOpt, toOpt) =>
      (for {
        companyId <- requireCompanyId(user)
        fromParam <- ZIO
                       .fromOption(fromOpt)
                       .orElseFail(ScheduleError.ValidationError("Query parameter 'from' is required"))
        toParam   <- ZIO
                       .fromOption(toOpt)
                       .orElseFail(ScheduleError.ValidationError("Query parameter 'to' is required"))
        fromDate  <- ZIO
                       .attempt(LocalDate.parse(fromParam))
                       .orElseFail(ScheduleError.ValidationError(s"Invalid 'from' date format: $fromParam"))
        toDate    <- ZIO
                       .attempt(LocalDate.parse(toParam))
                       .orElseFail(ScheduleError.ValidationError(s"Invalid 'to' date format: $toParam"))
        service   <- ZIO.service[ScheduleService]
        days      <- service.getScheduleForDateRange(companyId, fromDate, toDate)
      } yield days.map(ScheduleDayDto.fromDomain)).mapError(toError)
  }

  private val updateScheduleDayServer: ZServerEndpoint[ScheduleEnv, Any] = updateScheduleDayEndpoint.serverLogic {
    user => (id, apiRequest) =>
      (for {
        companyId <- requireCompanyId(user)
        validated <- apiRequest.validate
        domainReq  = UpdateScheduleDayApiRequest.toDomain(validated)
        schedId   <- ZIO
                       .attempt(ScheduleDayId(UUID.fromString(id)))
                       .orElseFail(ScheduleError.ValidationError("Invalid UUID format"))
        service   <- ZIO.service[ScheduleService]
        updated   <- service.updateScheduleDay(schedId, domainReq, companyId)
      } yield ScheduleDayDto.fromDomain(updated)).mapError(toError)
  }

  private val deleteScheduleDayServer: ZServerEndpoint[ScheduleEnv, Any] = deleteScheduleDayEndpoint.serverLogic {
    user => id =>
      (for {
        companyId <- requireCompanyId(user)
        schedId   <- ZIO
                       .attempt(ScheduleDayId(UUID.fromString(id)))
                       .orElseFail(ScheduleError.ValidationError("Invalid UUID format"))
        service   <- ZIO.service[ScheduleService]
        updated   <- service.cancelScheduleDay(schedId, companyId)
      } yield ScheduleDayDto.fromDomain(updated)).mapError(toError)
  }

  // -- Visibility server logic -------------------------------------------

  private val getCompanyVisibilityServer: ZServerEndpoint[ScheduleEnv, Any] = getCompanyVisibilityEndpoint.serverLogic {
    user => _ =>
      for {
        _         <- requireDispatcherOrAdmin(user)
        companyId <- requireCompanyId(user).mapError(toError)
        service   <- ZIO.service[ScheduleService]
        list      <- service.getCompanyVisibility(companyId).mapError(toError)
      } yield list.map(DriverScheduleVisibilityDto.fromDomain)
  }

  /**
   * GET /api/schedules/visibility/me — accessible to any authenticated user. Returns the caller's own visibility record
   * (defaults to canViewOtherSchedules=false when no record exists).
   */
  private val getMyVisibilityServer: ZServerEndpoint[ScheduleEnv, Any] = getMyVisibilityEndpoint.serverLogic {
    user => _ =>
      (for {
        companyId <- requireCompanyId(user)
        callerId   = PersonId(user.userId)
        service   <- ZIO.service[ScheduleService]
        result    <- service.getMyVisibility(callerId, companyId)
      } yield DriverScheduleVisibilityDto.fromDomain(result)).mapError(toError)
  }

  private val setDriverVisibilityServer: ZServerEndpoint[ScheduleEnv, Any] = setDriverVisibilityEndpoint.serverLogic {
    user => (driverIdStr, req) =>
      for {
        _         <- requireDispatcherOrAdmin(user)
        companyId <- requireCompanyId(user).mapError(toError)
        driverId  <- ZIO
                       .attempt(PersonId(UUID.fromString(driverIdStr)))
                       .orElseFail((StatusCode.BadRequest, ApiError("Invalid driver UUID format")))
        service   <- ZIO.service[ScheduleService]
        result    <- service.setDriverVisibility(driverId, companyId, req.canViewOtherSchedules).mapError(toError)
      } yield DriverScheduleVisibilityDto.fromDomain(result)
  }

  // -- Unavailability server logic ------------------------------------------

  /**
   * POST /api/schedules/unavailability — driver-only-self. Creates a manual unavailability window.
   */
  private val createUnavailabilityServer: ZServerEndpoint[ScheduleEnv, Any] = createUnavailabilityEndpoint.serverLogic {
    user => apiRequest =>
      (for {
        companyId     <- requireCompanyId(user)
        validRequest  <- apiRequest.validate
        domainRequest <- CreateDriverUnavailabilityApiRequest.toDomain(validRequest, companyId)
        requesterId    = PersonId(user.userId)
        service       <- ZIO.service[ScheduleService]
        result        <- service.createUnavailability(domainRequest, requesterId, user.role)
      } yield DriverUnavailabilityDto.fromDomain(result)).mapError(toError)
  }

  /**
   * GET /api/schedules/unavailability/driver/:driverId — access-controlled (mirrors getDriverScheduleAs).
   */
  private val getDriverUnavailabilityServer: ZServerEndpoint[ScheduleEnv, Any] = getDriverUnavailabilityEndpoint
    .serverLogic { user => driverId =>
      (for {
        companyId  <- requireCompanyId(user)
        driverPid  <- ZIO
                        .attempt(PersonId(UUID.fromString(driverId)))
                        .orElseFail(ScheduleError.ValidationError("Invalid UUID format"))
        requesterId = PersonId(user.userId)
        service    <- ZIO.service[ScheduleService]
        result     <- service.getDriverUnavailability(driverPid, companyId, requesterId, user.role)
      } yield result.map(DriverUnavailabilityDto.fromDomain)).mapError(toError)
    }

  /**
   * GET /api/schedules/unavailability?from=&to= — company-wide unavailability range view (dispatcher/admin only).
   *
   * Role guard mirrors `getCompanyVisibilityServer`: `requireDispatcherOrAdmin` runs first (already in the
   * `(StatusCode, ApiError)` error channel), then the inner business logic runs in `ScheduleError` and is converted to
   * `(StatusCode, ApiError)` via `.mapError(toError)`.
   */
  private val getCompanyUnavailabilityServer: ZServerEndpoint[ScheduleEnv, Any] = getCompanyUnavailabilityEndpoint
    .serverLogic { user => (fromOpt, toOpt) =>
      requireDispatcherOrAdmin(user) *> (for {
        companyId <- requireCompanyId(user)
        fromParam <- ZIO
                       .fromOption(fromOpt)
                       .orElseFail(ScheduleError.ValidationError("Query parameter 'from' is required"))
        toParam   <- ZIO
                       .fromOption(toOpt)
                       .orElseFail(ScheduleError.ValidationError("Query parameter 'to' is required"))
        from      <- ZIO
                       .attempt(Instant.parse(fromParam))
                       .orElseFail(ScheduleError.ValidationError(s"Invalid 'from' instant format: $fromParam"))
        to        <- ZIO
                       .attempt(Instant.parse(toParam))
                       .orElseFail(ScheduleError.ValidationError(s"Invalid 'to' instant format: $toParam"))
        service   <- ZIO.service[ScheduleService]
        result    <- service.getCompanyUnavailability(companyId, from, to)
      } yield result.map(DriverUnavailabilityDto.fromDomain)).mapError(toError)
    }

  /**
   * DELETE /api/schedules/unavailability/:id — owner-only (or dispatcher/admin).
   */
  private val deleteUnavailabilityServer: ZServerEndpoint[ScheduleEnv, Any] = deleteUnavailabilityEndpoint.serverLogic {
    user => id =>
      (for {
        companyId  <- requireCompanyId(user)
        unavailId  <- ZIO
                        .attempt(DriverUnavailabilityId(UUID.fromString(id)))
                        .orElseFail(ScheduleError.ValidationError("Invalid UUID format"))
        requesterId = PersonId(user.userId)
        service    <- ZIO.service[ScheduleService]
        _          <- service.deleteUnavailability(unavailId, requesterId, user.role, companyId)
      } yield ()).mapError(toError)
  }

  /**
   * All server endpoints, interpreted into zio-http Routes by the api module.
   *
   * NOTE: `getMyVisibilityServer` must appear before `setDriverVisibilityServer` so that Tapir routes `GET
   * /visibility/me` before attempting to match `PUT /visibility/:driverId`.
   *
   * NOTE: `getDriverUnavailabilityServer` (static "driver/..." prefix) must appear before `deleteUnavailabilityServer`
   * (dynamic "/:id" pattern) to avoid the static prefix being matched by the id segment.
   */
  val serverEndpoints: List[ZServerEndpoint[ScheduleEnv, Any]] = List(
    createScheduleDayServer,
    createScheduleBatchServer,
    getDriverScheduleServer,
    getScheduleForDateServer,
    getScheduleRangeServer,
    updateScheduleDayServer,
    deleteScheduleDayServer,
    getCompanyVisibilityServer,
    getMyVisibilityServer,
    setDriverVisibilityServer,
    createUnavailabilityServer,
    getDriverUnavailabilityServer,
    getCompanyUnavailabilityServer,
    deleteUnavailabilityServer
  )
