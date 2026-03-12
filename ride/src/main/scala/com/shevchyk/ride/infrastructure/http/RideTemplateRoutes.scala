package com.shevchyk.ride.infrastructure.http

import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.infrastructure.http.dto.{RideDto, given}
import com.shevchyk.ride.repository.RideTemplateRepository
import com.shevchyk.ride.application.service.RideService
import zio.*
import zio.http.*
import zio.json.*

import java.time.{Instant, LocalDate, LocalTime}

object RideTemplateRoutes:

  private def handleError(ex: Throwable): UIO[Response] =
    val msg = Option(ex.getMessage).getOrElse(ex.toString)
    ZIO
      .logError(s"RideTemplate error: $msg")
      .as(Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}""")))

  val authenticatedRoutes: Routes[RideTemplateRepository & RideService & JwtService, Response] = Routes(
    // POST /api/ride-templates — create template
    Method.POST / "api" / "ride-templates"                             -> handler { (request: Request) =>
      (for {
        user               <- AuthMiddleware.authenticateRequest(request)
        _                  <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY")
        bodyStr            <- request.body.asString
        req                <- ZIO
                                .fromEither(bodyStr.fromJson[CreateRideTemplateRequest])
                                .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        companyId          <- UuidParser.requireCompanyId(user.companyId)
        clientPid          <- UuidParser.parsePersonId(req.clientId)
        preferredDriverPid <- ZIO.foreach(req.preferredDriverId)(UuidParser.parsePersonId)
        template            = RideTemplate(
                                id = RideTemplateId.generate(),
                                companyId = companyId,
                                clientId = clientPid,
                                creatorId = PersonId(user.userId),
                                name = req.name,
                                fromAddress = req.fromAddress,
                                fromLat = req.fromLat,
                                fromLng = req.fromLng,
                                toAddress = req.toAddress,
                                toLat = req.toLat,
                                toLng = req.toLng,
                                preferredDriverId = preferredDriverPid,
                                notes = req.notes,
                                recurrencePattern = RecurrencePattern.valueOf(req.recurrencePattern),
                                recurrenceDays = req.recurrenceDays,
                                pickupTime = LocalTime.parse(req.pickupTime),
                                flightNumber = req.flightNumber,
                                isAirportTransfer = req.isAirportTransfer,
                                price = req.price.map(BigDecimal(_))
                              )
        repo               <- ZIO.service[RideTemplateRepository]
        created            <- repo.create(template)
      } yield Response(Status.Created, body = Body.fromString(created.toJson))).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },
    // GET /api/ride-templates — list templates for company
    Method.GET / "api" / "ride-templates"                              -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        repo      <- ZIO.service[RideTemplateRepository]
        templates <- repo.findActiveByCompanyId(companyId)
      } yield Response.json(templates.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },
    // DELETE /api/ride-templates/{id} — deactivate template
    Method.DELETE / "api" / "ride-templates" / string("id")            -> handler { (id: String, request: Request) =>
      (for {
        user        <- AuthMiddleware.authenticateRequest(request)
        _           <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY")
        repo        <- ZIO.service[RideTemplateRepository]
        tmplId      <- UuidParser.parse(id).map(RideTemplateId(_))
        deactivated <- repo.deactivate(tmplId)
      } yield if deactivated then Response(Status.NoContent) else Response.status(Status.NotFound)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },
    // POST /api/ride-templates/{id}/generate — generate rides from template for a date range
    Method.POST / "api" / "ride-templates" / string("id") / "generate" -> handler { (id: String, request: Request) =>
      (for {
        user    <- AuthMiddleware.authenticateRequest(request)
        _       <- AuthMiddleware.checkRole(user, "DISPATCHER", "SECRETARY")
        bodyStr <- request.body.asString
        genReq  <- ZIO
                     .fromEither(bodyStr.fromJson[GenerateRidesRequest])
                     .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        repo    <- ZIO.service[RideTemplateRepository]
        tmplId  <- UuidParser.parse(id).map(RideTemplateId(_))
        tmplOpt <- repo.findById(tmplId)
        tmpl    <- ZIO.fromOption(tmplOpt).orElseFail(new RuntimeException("Template not found"))
        from     = LocalDate.parse(genReq.fromDate)
        to       = LocalDate.parse(genReq.toDate)
        dates    = generateDates(tmpl, from, to)
        service <- ZIO.service[RideService]
        rides   <-
          ZIO.foreach(dates) { date =>
            val scheduledInstant = date.atTime(tmpl.pickupTime).toInstant(java.time.ZoneOffset.UTC)
            val specifics        =
              if (tmpl.isAirportTransfer)
                Some(RideSpecifics.AirportTransfer("UNKNOWN", tmpl.flightNumber.getOrElse("")))
              else
                None
            val createReq        = CreateRideRequest(
              clientId = tmpl.clientId,
              companyId = tmpl.companyId,
              pickupLocation = Location(tmpl.fromAddress, tmpl.fromLat, tmpl.fromLng),
              dropoffLocation = Location(tmpl.toAddress, tmpl.toLat, tmpl.toLng),
              scheduledTime = Some(scheduledInstant),
              notes = tmpl.notes,
              specifics = specifics
            )
            service.createRide(createReq)
          }
        rideDtos = rides.map(r => com.shevchyk.ride.infrastructure.http.dto.RideDto.fromDomain(r))
      } yield Response(Status.Created, body = Body.fromString(rideDtos.toJson))).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    }
  )

  private def generateDates(template: RideTemplate, from: LocalDate, to: LocalDate): List[LocalDate] =
    import java.time.DayOfWeek
    val allDates = Iterator.iterate(from)(_.plusDays(1)).takeWhile(!_.isAfter(to)).toList
    template.recurrencePattern match
      case RecurrencePattern.DAILY      => allDates
      case RecurrencePattern.WEEKDAYS   =>
        allDates.filter(d => d.getDayOfWeek != DayOfWeek.SATURDAY && d.getDayOfWeek != DayOfWeek.SUNDAY)
      case RecurrencePattern.WEEKLY_MON => allDates.filter(_.getDayOfWeek == DayOfWeek.MONDAY)
      case RecurrencePattern.WEEKLY_TUE => allDates.filter(_.getDayOfWeek == DayOfWeek.TUESDAY)
      case RecurrencePattern.WEEKLY_WED => allDates.filter(_.getDayOfWeek == DayOfWeek.WEDNESDAY)
      case RecurrencePattern.WEEKLY_THU => allDates.filter(_.getDayOfWeek == DayOfWeek.THURSDAY)
      case RecurrencePattern.WEEKLY_FRI => allDates.filter(_.getDayOfWeek == DayOfWeek.FRIDAY)
      case RecurrencePattern.WEEKLY_SAT => allDates.filter(_.getDayOfWeek == DayOfWeek.SATURDAY)
      case RecurrencePattern.WEEKLY_SUN => allDates.filter(_.getDayOfWeek == DayOfWeek.SUNDAY)
      case RecurrencePattern.CUSTOM     =>
        val days = template.recurrenceDays
          .map(_.split(",").map(_.trim.toInt).toSet)
          .getOrElse(Set.empty)
        allDates.filter(d => days.contains(d.getDayOfWeek.getValue))
