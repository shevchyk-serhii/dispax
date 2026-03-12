package com.shevchyk.schedule.infrastructure.http

import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, PersonId, ScheduleDayId}
import com.shevchyk.schedule.application.ScheduleService
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.infrastructure.http.dto.{*, given}
import com.shevchyk.schedule.validation.given
import com.shevchyk.schedule.validation.Validator.validate
import zio.*
import zio.http.*
import zio.json.*

import java.time.LocalDate

object ScheduleRoutes:

  val authenticatedRoutes: Routes[ScheduleService & JwtService, Response] = Routes(
    // POST /api/schedules — Create single schedule day
    Method.POST / "api" / "schedules" -> authenticatedJsonHandler[ScheduleService, CreateScheduleDayApiRequest] {
      (user, apiRequest) =>
        (for {
          companyId     <- ZIO
                             .fromOption(user.companyId)
                             .mapError(_ => ScheduleError.ValidationError("User must belong to a company"))
                             .map(CompanyId(_))
          validRequest  <- apiRequest.validate
          domainRequest <- CreateScheduleDayApiRequest.toDomain(validRequest, companyId)
          service       <- ZIO.service[ScheduleService]
          scheduleDay   <- service.createScheduleDay(domainRequest)
          dto            = ScheduleDayDto.fromDomain(scheduleDay)
        } yield Response(Status.Created, body = Body.fromString(dto.toJson)))
          .catchAll(handleScheduleError)
    },

    // POST /api/schedules/batch — Create multiple schedule days
    Method.POST / "api" / "schedules" / "batch" -> authenticatedJsonHandler[
      ScheduleService,
      CreateScheduleBatchApiRequest
    ] { (user, apiRequest) =>
      (for {
        companyId     <- ZIO
                           .fromOption(user.companyId)
                           .mapError(_ => ScheduleError.ValidationError("User must belong to a company"))
                           .map(CompanyId(_))
        validRequest  <- apiRequest.validate
        domainRequest <- CreateScheduleBatchApiRequest.toDomain(validRequest, companyId)
        service       <- ZIO.service[ScheduleService]
        days          <- service.createBatch(domainRequest)
        dtos           = days.map(ScheduleDayDto.fromDomain)
      } yield Response(Status.Created, body = Body.fromString(dtos.toJson)))
        .catchAll(handleScheduleError)
    },

    // GET /api/schedules/driver/{driverId} — Driver's schedule (company-scoped)
    Method.GET / "api" / "schedules" / "driver" / string("driverId") -> handler {
      (driverId: String, request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          companyId <- ZIO
                         .fromOption(user.companyId)
                         .mapError(_ => ScheduleError.ValidationError("User must belong to a company"))
                         .map(CompanyId(_))
          driverPid <- UuidParser.parsePersonId(driverId)
          service   <- ZIO.service[ScheduleService]
          days      <- service.getDriverSchedule(
                         driverPid,
                         companyId
                       )
          dtos       = days.map(ScheduleDayDto.fromDomain)
        } yield Response.json(dtos.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleScheduleError(ex)
        }
    },

    // GET /api/schedules/day/{date} — All drivers for a date (company-scoped)
    Method.GET / "api" / "schedules" / "day" / string("date") -> handler { (date: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        companyId <- ZIO
                       .fromOption(user.companyId)
                       .mapError(_ => ScheduleError.ValidationError("User must belong to a company"))
                       .map(CompanyId(_))
        localDate <- ZIO
                       .attempt(LocalDate.parse(date))
                       .orElseFail(ScheduleError.ValidationError(s"Invalid date format: $date"))
        service   <- ZIO.service[ScheduleService]
        days      <- service.getScheduleForDate(companyId, localDate)
        dtos       = days.map(ScheduleDayDto.fromDomain)
      } yield Response.json(dtos.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleScheduleError(ex)
      }
    },

    // GET /api/schedules?from=&to= — Date range query (company-scoped)
    Method.GET / "api" / "schedules" -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        companyId <- ZIO
                       .fromOption(user.companyId)
                       .mapError(_ => ScheduleError.ValidationError("User must belong to a company"))
                       .map(CompanyId(_))
        fromParam <- ZIO
                       .fromOption(request.url.queryParams.queryParam("from"))
                       .orElseFail(ScheduleError.ValidationError("Query parameter 'from' is required"))
        toParam   <- ZIO
                       .fromOption(request.url.queryParams.queryParam("to"))
                       .orElseFail(ScheduleError.ValidationError("Query parameter 'to' is required"))
        fromDate  <- ZIO
                       .attempt(LocalDate.parse(fromParam))
                       .orElseFail(ScheduleError.ValidationError(s"Invalid 'from' date format: $fromParam"))
        toDate    <- ZIO
                       .attempt(LocalDate.parse(toParam))
                       .orElseFail(ScheduleError.ValidationError(s"Invalid 'to' date format: $toParam"))
        service   <- ZIO.service[ScheduleService]
        days      <- service.getScheduleForDateRange(companyId, fromDate, toDate)
        dtos       = days.map(ScheduleDayDto.fromDomain)
      } yield Response.json(dtos.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleScheduleError(ex)
      }
    },

    // PUT /api/schedules/{id} — Update schedule day
    Method.PUT / "api" / "schedules" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user       <- AuthMiddleware.authenticateRequest(request)
        companyId  <- ZIO
                        .fromOption(user.companyId)
                        .mapError(_ => ScheduleError.ValidationError("User must belong to a company"))
                        .map(CompanyId(_))
        bodyStr    <- request.body.asString
        apiRequest <- ZIO
                        .fromEither(bodyStr.fromJson[UpdateScheduleDayApiRequest])
                        .mapError(err => ScheduleError.ValidationError(s"Invalid JSON: $err"))
        validated  <- apiRequest.validate
        domainReq   = UpdateScheduleDayApiRequest.toDomain(validated)
        schedId    <- UuidParser.parse(id).map(ScheduleDayId(_))
        service    <- ZIO.service[ScheduleService]
        updated    <- service.updateScheduleDay(
                        schedId,
                        domainReq,
                        companyId
                      )
        dto         = ScheduleDayDto.fromDomain(updated)
      } yield Response.json(dto.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleScheduleError(ex)
      }
    },

    // DELETE /api/schedules/{id} — Cancel schedule day
    Method.DELETE / "api" / "schedules" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        companyId <- ZIO
                       .fromOption(user.companyId)
                       .mapError(_ => ScheduleError.ValidationError("User must belong to a company"))
                       .map(CompanyId(_))
        schedId   <- UuidParser.parse(id).map(ScheduleDayId(_))
        service   <- ZIO.service[ScheduleService]
        updated   <- service.cancelScheduleDay(
                       schedId,
                       companyId
                     )
        dto        = ScheduleDayDto.fromDomain(updated)
      } yield Response.json(dto.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleScheduleError(ex)
      }
    }
  )

  private def handleScheduleError(ex: Throwable): UIO[Response] =
    val (status, msg) =
      ex match
        case ScheduleError.ValidationError(message)             => (Status.BadRequest, message)
        case ScheduleError.ScheduleDayNotFound(id)              => (Status.NotFound, s"Schedule day not found: ${id.value}")
        case ScheduleError.DriverNotFound(id)                   => (Status.NotFound, s"Driver not found: ${id.value}")
        case ScheduleError.DuplicateScheduleDay(driverId, date) =>
          (Status.Conflict, s"Driver ${driverId.value} already has a schedule for $date")
        case ScheduleError.InvalidStatusTransition(from, to)    =>
          (Status.Conflict, s"Cannot transition from $from to $to")
        case ScheduleError.CompanyMismatch(expected, actual)    =>
          (Status.Forbidden, "Schedule day belongs to a different company")
        case ScheduleError.DatabaseError(_)                     => (Status.InternalServerError, "Internal server error")
        case _                                                  => (Status.InternalServerError, "Internal server error")

    ZIO
      .logError(s"Schedule error: $msg")
      .as(Response(status, body = Body.fromString(s"""{"error":"$msg"}""")))
