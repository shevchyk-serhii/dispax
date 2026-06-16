package com.shevchyk.schedule.openapi

import com.shevchyk.auth.domain.{ExpiredTokenError, InvalidTokenError, JwtError}
import com.shevchyk.auth.middleware.AuthenticatedUser
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, PersonId, ScheduleDayId}
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.schedule.application.ScheduleService
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.infrastructure.http.dto.{*, given}
import com.shevchyk.schedule.validation.given
import com.shevchyk.schedule.validation.Validator.validate
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

import java.time.LocalDate
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

  private def toError(ex: Throwable): (StatusCode, ApiError) =
    ex match
      case ScheduleError.ValidationError(message)             => (StatusCode.BadRequest, ApiError(message))
      case ScheduleError.ScheduleDayNotFound(id)              =>
        (StatusCode.NotFound, ApiError(s"Schedule day not found: ${id.value}"))
      case ScheduleError.DriverNotFound(id)                   => (StatusCode.NotFound, ApiError(s"Driver not found: ${id.value}"))
      case ScheduleError.DuplicateScheduleDay(driverId, date) =>
        (StatusCode.Conflict, ApiError(s"Driver ${driverId.value} already has a schedule for $date"))
      case ScheduleError.InvalidStatusTransition(from, to)    =>
        (StatusCode.Conflict, ApiError(s"Cannot transition from $from to $to"))
      case ScheduleError.CompanyMismatch(_, _)                =>
        (StatusCode.Forbidden, ApiError("Schedule day belongs to a different company"))
      case ScheduleError.DatabaseError(_)                     => (StatusCode.InternalServerError, ApiError("Internal server error"))
      case _                                                  => (StatusCode.InternalServerError, ApiError("Internal server error"))

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
    .summary("Get a driver's schedule")

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
    deleteScheduleDayEndpoint
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

  private val getDriverScheduleServer: ZServerEndpoint[ScheduleEnv, Any] = getDriverScheduleEndpoint.serverLogic {
    user => driverId =>
      (for {
        companyId <- requireCompanyId(user)
        driverPid <- ZIO
                       .attempt(PersonId(UUID.fromString(driverId)))
                       .orElseFail(ScheduleError.ValidationError("Invalid UUID format"))
        service   <- ZIO.service[ScheduleService]
        days      <- service.getDriverSchedule(driverPid, companyId)
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

  /**
   * All server endpoints, interpreted into zio-http Routes by the api module.
   */
  val serverEndpoints: List[ZServerEndpoint[ScheduleEnv, Any]] = List(
    createScheduleDayServer,
    createScheduleBatchServer,
    getDriverScheduleServer,
    getScheduleForDateServer,
    getScheduleRangeServer,
    updateScheduleDayServer,
    deleteScheduleDayServer
  )
