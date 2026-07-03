package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AuditService, EventHub}
import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.{BlacklistRepository, EmergencyReassignmentRepository, PersonRepository}
import com.shevchyk.ride.application.service.RideService
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*

import java.time.Instant

/**
 * Tapir descriptions and server logic for the emergency-reassignment endpoints. Replaces the hand-written zio-http
 * handlers in `EmergencyRoutes` while preserving paths, role checks, business rules, audit logging, websocket events,
 * status codes and error mapping.
 */
object EmergencyApi:

  import AppSecure.*
  import ApiSchemas.given

  private val emergencyTag = "Emergency"

  /**
   * `EmergencyReassignment` enriched with the driver display names so the UI never has to show a bare UUID. Names are
   * resolved at read time; a name is `None` when the person no longer exists (or no new driver is set).
   */
  final case class EmergencyReassignmentDto(
      id: EmergencyReassignmentId,
      rideId: RideId,
      companyId: CompanyId,
      originalDriverId: PersonId,
      newDriverId: Option[PersonId],
      reason: EmergencyReason,
      notes: Option[String],
      reassignedBy: PersonId,
      createdAt: Instant,
      status: ReassignmentStatus,
      originalDriverName: Option[String],
      newDriverName: Option[String]
  ) derives JsonCodec

  object EmergencyReassignmentDto:

    def fromDomain(r: EmergencyReassignment, names: Map[PersonId, String]): EmergencyReassignmentDto =
      EmergencyReassignmentDto(
        id = r.id,
        rideId = r.rideId,
        companyId = r.companyId,
        originalDriverId = r.originalDriverId,
        newDriverId = r.newDriverId,
        reason = r.reason,
        notes = r.notes,
        reassignedBy = r.reassignedBy,
        createdAt = r.createdAt,
        status = r.status,
        originalDriverName = names.get(r.originalDriverId),
        newDriverName = r.newDriverId.flatMap(names.get)
      )

  type EmergencyEnv =
    JwtService & EmergencyReassignmentRepository & BlacklistRepository & RideService & PersonRepository & AuditService &
      EventHub

  // -- Endpoint descriptions ------------------------------------------------

  val reassignEndpoint = secureEndpoint.post
    .in("api" / "emergency" / "reassign")
    .in(jsonBody[EmergencyReassignRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[EmergencyReassignment]))
    .tag(emergencyTag)
    .summary("Initiate an emergency reassignment (dispatcher)")

  val listReassignmentsEndpoint = secureEndpoint.get
    .in("api" / "emergency" / "reassignments")
    .out(jsonBody[List[EmergencyReassignmentDto]])
    .tag(emergencyTag)
    .summary("List emergency reassignments for the company (dispatcher)")

  val suggestDriversEndpoint = secureEndpoint.get
    .in("api" / "emergency" / "suggest-drivers" / path[String]("rideId"))
    .out(jsonBody[List[Map[String, String]]])
    .tag(emergencyTag)
    .summary("Suggest available drivers for reassignment (dispatcher)")

  val endpoints = List(reassignEndpoint, listReassignmentsEndpoint, suggestDriversEndpoint)

  // -- Server logic ---------------------------------------------------------

  private val reassignServer: ZServerEndpoint[EmergencyEnv, Any] = reassignEndpoint.serverLogic[EmergencyEnv] {
    user => req =>
      for {
        _                <- checkRole(user, "DISPATCHER")
        companyId        <- requireCompanyId(user.companyId)
        rideService      <- ZIO.service[RideService]
        rideId           <- parseRideId(req.rideId)
        ride             <- rideService.getRideById(rideId).mapError(e => internal(new RuntimeException(e.toString)))
        // Enforce tenant isolation: a dispatcher must not initiate an emergency
        // reassignment on a ride that belongs to another company. NotFound to
        // avoid leaking cross-tenant existence.
        _                <- ZIO
                              .fail((StatusCode.NotFound, ApiError("Not found")): Err)
                              .when(ride.companyId != companyId)
        _                <- ZIO
                              .fail(internal(new RuntimeException("Ride must be assigned or in progress for emergency reassignment")))
                              .when(
                                ride.status != com.shevchyk.ride.domain.RideStatus.Assigned &&
                                  ride.status != com.shevchyk.ride.domain.RideStatus.InProgress
                              )
        originalDriverId <- ZIO
                              .fromOption(ride.driverId)
                              .orElseFail(internal(new RuntimeException("Ride has no assigned driver")))
        reason           <- ZIO
                              .attempt(EmergencyReason.valueOf(req.reason))
                              .mapError(_ => internal(new RuntimeException(s"Invalid reason: ${req.reason}")))
        emergRepo        <- ZIO.service[EmergencyReassignmentRepository]
        newDriverIdOpt   <- ZIO.foreach(req.newDriverId)(parsePersonId)
        reassignment      = EmergencyReassignment(
                              id = EmergencyReassignmentId.generate(),
                              rideId = ride.id,
                              companyId = ride.companyId,
                              originalDriverId = originalDriverId,
                              newDriverId = newDriverIdOpt,
                              reason = reason,
                              notes = req.notes,
                              reassignedBy = PersonId(user.userId)
                            )
        created          <- emergRepo.create(reassignment).mapError(internal)
        _                <-
          req.newDriverId match
            case Some(newId) =>
              for {
                newDriverPid <- parsePersonId(newId)
                blRepo       <- ZIO.service[BlacklistRepository]
                blocked      <- blRepo.isBlacklisted(ride.clientId, newDriverPid).mapError(internal)
                _            <- ZIO
                                  .fail(internal(new RuntimeException("New driver is blacklisted for this client")))
                                  .when(blocked)
                // allowPastRide: an emergency (accident, breakdown) typically strikes a ride at/after its pickup
                // time, so the regular past-ride reassignment guard must not block this flow.
                _            <- rideService
                                  .reassignDriver(ride.id, newDriverPid, allowPastRide = true)
                                  .mapError(e => internal(new RuntimeException(e.toString)))
                _            <- emergRepo
                                  .updateStatus(created.id, ReassignmentStatus.REASSIGNED, Some(newDriverPid))
                                  .mapError(internal)
              } yield ()
            case None        => ZIO.unit
        audit            <- ZIO.service[AuditService]
        _                <-
          audit
            .log(
              AuditLogEntry.record(
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
        eventHub         <- ZIO.service[EventHub]
        _                <-
          eventHub
            .publish(
              WebSocketEvent.RideStatusChanged(
                rideId = ride.id.value,
                newStatus = "EmergencyReassignment",
                driverId = Some(originalDriverId.value),
                clientId = ride.clientId.value,
                companyId = ride.companyId.value
              )
            )
            .ignore
      } yield created
  }

  private val listReassignmentsServer: ZServerEndpoint[EmergencyEnv, Any] = listReassignmentsEndpoint
    .serverLogic[EmergencyEnv] { user => _ =>
      for {
        _             <- checkRole(user, "DISPATCHER")
        repo          <- ZIO.service[EmergencyReassignmentRepository]
        companyId     <- requireCompanyId(user.companyId)
        reassignments <- repo.findByCompanyId(companyId).mapError(internal)
        names         <- PersonNameLookup
                           .names(reassignments.flatMap(r => r.originalDriverId :: r.newDriverId.toList), companyId)
                           .mapError(internal)
      } yield reassignments.map(EmergencyReassignmentDto.fromDomain(_, names))
    }

  private val suggestDriversServer: ZServerEndpoint[EmergencyEnv, Any] = suggestDriversEndpoint
    .serverLogic[EmergencyEnv] { user => rideId =>
      for {
        _            <- checkRole(user, "DISPATCHER")
        companyId    <- requireCompanyId(user.companyId)
        rideService  <- ZIO.service[RideService]
        parsedRideId <- parseRideId(rideId)
        ride         <- rideService.getRideById(parsedRideId).mapError(e => internal(new RuntimeException(e.toString)))
        // Enforce tenant isolation: a dispatcher must not enumerate drivers/
        // clients of a ride that belongs to another company. NotFound to avoid
        // leaking cross-tenant existence.
        _            <- ZIO
                          .fail((StatusCode.NotFound, ApiError("Not found")): Err)
                          .when(ride.companyId != companyId)
        personRepo   <- ZIO.service[PersonRepository]
        drivers      <- personRepo.findByCompanyId(ride.companyId).mapError(internal)
        blackRepo    <- ZIO.service[BlacklistRepository]
        candidates   <-
          ZIO
            .filter(drivers.filter(d => d.hasRole(PersonRole.Driver) && !ride.driverId.contains(d.id)))(d =>
              blackRepo.isBlacklisted(ride.clientId, d.id).map(!_).mapError(internal)
            )
        clientRepo   <- personRepo.findById(ride.clientId).mapError(internal)
        preferredId   = clientRepo.flatMap(_.preferredDriverId)
        sorted        = candidates.sortBy(d => if preferredId.contains(d.id) then 0 else 1)
        result        = sorted.map(d =>
                          Map(
                            "id"          -> d.id.value.toString,
                            "name"        -> d.name,
                            "phone"       -> d.phone.getOrElse(""),
                            "isPreferred" -> preferredId.contains(d.id).toString
                          )
                        )
      } yield result
    }

  val serverEndpoints: List[ZServerEndpoint[EmergencyEnv, Any]] = List(
    reassignServer,
    listReassignmentsServer,
    suggestDriversServer
  )
