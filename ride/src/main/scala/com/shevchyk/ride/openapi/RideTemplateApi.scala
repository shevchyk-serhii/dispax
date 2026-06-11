package com.shevchyk.ride.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{Location, PersonId}
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.infrastructure.http.dto.{RideDto, given}
import com.shevchyk.ride.openapi.RideSchemas.given
import com.shevchyk.ride.openapi.RideSecure.*
import com.shevchyk.ride.repository.RideTemplateRepository
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

import java.time.{DayOfWeek, LocalDate, LocalTime}

/**
 * Tapir descriptions and server logic for the ride-template endpoints. Replaces the zio-http handlers in
 * `RideTemplateRoutes`, keeping the exact paths, status codes, role checks and company isolation. Unexpected failures
 * (invalid JSON, "Template not found", bad parse) map to a 500 just like the original `RouteErrorHandler`.
 */
object RideTemplateApi:

  private val templateTag = "Ride templates"

  type RideTemplateEnv = RideTemplateRepository & RideService & JwtService

  private def internalError: Err = (StatusCode.InternalServerError, ApiError("Internal server error"))

  // -- Endpoint descriptions -----------------------------------------------

  val createTemplateEndpoint =
    secureEndpoint.post
      .in("api" / "ride-templates")
      .in(jsonBody[CreateRideTemplateRequest])
      .out(statusCode(StatusCode.Created).and(jsonBody[RideTemplate]))
      .tag(templateTag)
      .summary("Create a ride template")

  val listTemplatesEndpoint =
    secureEndpoint.get
      .in("api" / "ride-templates")
      .out(jsonBody[List[RideTemplate]])
      .tag(templateTag)
      .summary("List active ride templates for the company")

  val deleteTemplateEndpoint =
    secureEndpoint.delete
      .in("api" / "ride-templates" / path[String]("id"))
      .out(statusCode(StatusCode.NoContent))
      .tag(templateTag)
      .summary("Deactivate a ride template")

  val generateRidesEndpoint =
    secureEndpoint.post
      .in("api" / "ride-templates" / path[String]("id") / "generate")
      .in(jsonBody[GenerateRidesRequest])
      .out(statusCode(StatusCode.Created).and(jsonBody[List[RideDto]]))
      .tag(templateTag)
      .summary("Generate rides from a template for a date range")

  val endpoints = List(createTemplateEndpoint, listTemplatesEndpoint, deleteTemplateEndpoint, generateRidesEndpoint)

  // -- Server logic --------------------------------------------------------

  private val createTemplateServer: ZServerEndpoint[RideTemplateEnv, Any] =
    createTemplateEndpoint.serverLogic { user => req =>
      (for {
        _                  <- checkRole(user, "DISPATCHER", "SECRETARY")
        companyId          <- requireCompanyId(user.companyId)
        clientPid          <- parsePersonId(req.clientId)
        preferredDriverPid <- ZIO.foreach(req.preferredDriverId)(parsePersonId)
        template           <- ZIO
                                .attempt(
                                  RideTemplate(
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
                                )
                                .mapError(_ => internalError)
        repo               <- ZIO.service[RideTemplateRepository]
        created            <- repo.create(template).mapError(_ => internalError)
      } yield created)
    }

  private val listTemplatesServer: ZServerEndpoint[RideTemplateEnv, Any] =
    listTemplatesEndpoint.serverLogic { user => _ =>
      (for {
        _         <- checkRole(user, "DISPATCHER", "SECRETARY")
        companyId <- requireCompanyId(user.companyId)
        repo      <- ZIO.service[RideTemplateRepository]
        templates <- repo.findActiveByCompanyId(companyId).mapError(_ => internalError)
      } yield templates)
    }

  private val deleteTemplateServer: ZServerEndpoint[RideTemplateEnv, Any] =
    deleteTemplateEndpoint.serverLogic { user => id =>
      (for {
        _           <- checkRole(user, "DISPATCHER", "SECRETARY")
        companyId   <- requireCompanyId(user.companyId)
        repo        <- ZIO.service[RideTemplateRepository]
        tmplId      <- parseUuid(id).map(RideTemplateId(_))
        // Enforce tenant isolation: findById/deactivate are not company-scoped,
        // so verify ownership before deactivating; cross-tenant id → NotFound.
        tmplOpt     <- repo.findById(tmplId).mapError(_ => internalError)
        deactivated <- tmplOpt.filter(_.companyId == companyId) match
                         case Some(_) => repo.deactivate(tmplId).mapError(_ => internalError)
                         case None    => ZIO.succeed(false)
        _           <- ZIO.fail((StatusCode.NotFound, ApiError("Not found"))).when(!deactivated)
      } yield ())
    }

  private val generateRidesServer: ZServerEndpoint[RideTemplateEnv, Any] =
    generateRidesEndpoint.serverLogic { user => (id, genReq) =>
      (for {
        _         <- checkRole(user, "DISPATCHER", "SECRETARY")
        companyId <- requireCompanyId(user.companyId)
        repo    <- ZIO.service[RideTemplateRepository]
        tmplId  <- parseUuid(id).map(RideTemplateId(_))
        tmplOpt <- repo.findById(tmplId).mapError(_ => internalError)
        // Enforce tenant isolation: only generate rides from a template that
        // belongs to the caller's company; cross-tenant id → NotFound.
        tmpl    <- ZIO
                     .fromOption(tmplOpt.filter(_.companyId == companyId))
                     .orElseFail((StatusCode.NotFound, ApiError("Not found")))
        range   <- ZIO
                     .attempt((LocalDate.parse(genReq.fromDate), LocalDate.parse(genReq.toDate)))
                     .mapError(_ => internalError)
        (from, to) = range
        dates    = generateDates(tmpl, from, to)
        service <- ZIO.service[RideService]
        rides   <- ZIO
                     .foreach(dates) { date =>
                       val scheduledInstant = date.atTime(tmpl.pickupTime).toInstant(java.time.ZoneOffset.UTC)
                       val specifics        =
                         if (tmpl.isAirportTransfer)
                           Some(RideSpecifics.AirportTransfer("UNKNOWN", tmpl.flightNumber.getOrElse("")))
                         else None
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
                     .mapError(_ => internalError)
      } yield rides.map(r => RideDto.fromDomain(r)))
    }

  private def generateDates(template: RideTemplate, from: LocalDate, to: LocalDate): List[LocalDate] =
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

  val serverEndpoints: List[ZServerEndpoint[RideTemplateEnv, Any]] =
    List(createTemplateServer, listTemplatesServer, deleteTemplateServer, generateRidesServer)
