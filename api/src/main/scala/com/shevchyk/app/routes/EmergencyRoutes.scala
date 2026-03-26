package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.core.repository.{EmergencyReassignmentRepository, BlacklistRepository}
import com.shevchyk.core.application.{AuditService, EventHub}
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.core.infrastructure.http.RouteErrorHandler
import zio.*
import zio.http.*
import zio.json.*

import java.time.Instant

object EmergencyRoutes:

  private def handleError(ex: Throwable): UIO[Response] = RouteErrorHandler.handleError("Emergency")(ex)

  val authenticatedRoutes
      : Routes[EmergencyReassignmentRepository & BlacklistRepository & RideService & PersonRepository & AuditService & EventHub & JwtService, Response] =
    Routes(
      // POST /api/emergency/reassign — initiate emergency reassignment
      Method.POST / "api" / "emergency" / "reassign" -> handler { (request: Request) =>
        (for {
          user             <- AuthMiddleware.authenticateRequest(request)
          _                <- AuthMiddleware.checkRole(user, "DISPATCHER")
          bodyStr          <- request.body.asString
          req              <- ZIO
                                .fromEither(bodyStr.fromJson[EmergencyReassignRequest])
                                .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          rideService      <- ZIO.service[RideService]
          rideId           <- UuidParser.parseRideId(req.rideId)
          ride             <- rideService
                                .getRideById(rideId)
                                .mapError(e => new RuntimeException(e.toString))

          // Ride must be assigned or in progress
          _                <- ZIO
                                .fail(new RuntimeException("Ride must be assigned or in progress for emergency reassignment"))
                                .when(
                                  ride.status != com.shevchyk.ride.domain.RideStatus.Assigned && ride.status != com.shevchyk.ride.domain.RideStatus.InProgress
                                )
          originalDriverId <- ZIO
                                .fromOption(ride.driverId)
                                .orElseFail(new RuntimeException("Ride has no assigned driver"))

          reason <- ZIO
                      .attempt(EmergencyReason.valueOf(req.reason))
                      .orElseFail(new RuntimeException(s"Invalid reason: ${req.reason}"))

          emergRepo      <- ZIO.service[EmergencyReassignmentRepository]
          newDriverIdOpt <- ZIO.foreach(req.newDriverId)(UuidParser.parsePersonId)
          reassignment    = EmergencyReassignment(
                              id = EmergencyReassignmentId.generate(),
                              rideId = ride.id,
                              companyId = ride.companyId,
                              originalDriverId = originalDriverId,
                              newDriverId = newDriverIdOpt,
                              reason = reason,
                              notes = req.notes,
                              reassignedBy = PersonId(user.userId)
                            )
          created        <- emergRepo.create(reassignment)

          // If new driver specified, do the reassignment immediately
          _ <-
            req.newDriverId match
              case Some(newId) =>
                for {
                  newDriverPid <- UuidParser.parsePersonId(newId)
                  // Check blacklist
                  blRepo       <- ZIO.service[BlacklistRepository]
                  blocked      <- blRepo.isBlacklisted(ride.clientId, newDriverPid)
                  _            <- ZIO
                                    .fail(new RuntimeException("New driver is blacklisted for this client"))
                                    .when(blocked)
                  _            <- rideService
                                    .reassignDriver(ride.id, newDriverPid)
                                    .mapError(e => new RuntimeException(e.toString))
                  _            <- emergRepo.updateStatus(created.id, ReassignmentStatus.REASSIGNED, Some(newDriverPid))
                } yield ()
              case None        =>
                // Unassign driver, set ride back to Requested
                ZIO.unit // Leave as PENDING for dispatcher to manually reassign

          audit <- ZIO.service[AuditService]
          _     <-
            audit
              .log(
                AuditLogEntry(
                  id = AuditLogId.generate(),
                  companyId = ride.companyId,
                  actorId = PersonId(user.userId),
                  action = AuditAction.RideReassigned,
                  entityType = "emergency_reassignment",
                  entityId = created.id.value,
                  oldValue = Some(s"driver=${originalDriverId.value}"),
                  newValue = req.newDriverId.map(d => s"driver=$d")
                )
              )
              .ignore

          eventHub <- ZIO.service[EventHub]
          _        <-
            eventHub
              .publish(
                WebSocketEvent.RideStatusChanged(
                  rideId = ride.id.value,
                  newStatus = "EmergencyReassignment",
                  driverId = Some(originalDriverId.value),
                  companyId = ride.companyId.value
                )
              )
              .ignore
        } yield Response(Status.Created, body = Body.fromString(created.toJson))).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // GET /api/emergency/reassignments — list emergency reassignments for company
      Method.GET / "api" / "emergency" / "reassignments" -> handler { (request: Request) =>
        (for {
          user          <- AuthMiddleware.authenticateRequest(request)
          _             <- AuthMiddleware.checkRole(user, "DISPATCHER")
          repo          <- ZIO.service[EmergencyReassignmentRepository]
          companyId     <- UuidParser.requireCompanyId(user.companyId)
          reassignments <- repo.findByCompanyId(companyId)
        } yield Response.json(reassignments.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // GET /api/emergency/suggest-drivers/{rideId} — suggest available drivers for reassignment
      Method.GET / "api" / "emergency" / "suggest-drivers" / string("rideId") -> handler {
        (rideId: String, request: Request) =>
          (for {
            user         <- AuthMiddleware.authenticateRequest(request)
            _            <- AuthMiddleware.checkRole(user, "DISPATCHER")
            rideService  <- ZIO.service[RideService]
            parsedRideId <- UuidParser.parseRideId(rideId)
            ride         <- rideService
                              .getRideById(parsedRideId)
                              .mapError(e => new RuntimeException(e.toString))
            personRepo   <- ZIO.service[PersonRepository]
            drivers      <- personRepo.findByCompanyId(ride.companyId)
            blackRepo    <- ZIO.service[BlacklistRepository]
            // Filter out current driver, blacklisted, and non-drivers
            candidates   <-
              ZIO.filter(
                drivers.filter(d => d.role == PersonRole.Driver && !ride.driverId.contains(d.id))
              )(d => blackRepo.isBlacklisted(ride.clientId, d.id).map(!_))

            // Sort: preferred driver first, then by name
            clientRepo   <- personRepo.findById(ride.clientId)
            preferredId   = clientRepo.flatMap(_.preferredDriverId)
            sorted        = candidates.sortBy(d => if preferredId.contains(d.id) then 0 else 1)

            result = sorted.map(d =>
                       Map(
                         "id"          -> d.id.value.toString,
                         "name"        -> d.name,
                         "phone"       -> d.phone.getOrElse(""),
                         "isPreferred" -> preferredId.contains(d.id).toString
                       )
                     )
          } yield Response.json(result.toJson)).catchAll {
            case response: Response => ZIO.succeed(response)
            case ex: Throwable      => handleError(ex)
          }
      }
    )
