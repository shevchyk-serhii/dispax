package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{
  DriverAvailabilityChecker,
  EventHub,
  AuditService,
  GeocodingService,
  ScheduleDayLookup
}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.domain.RepositoryExtensions.*
import com.shevchyk.ride.repository.{
  ExpenseRepository,
  ExternalDriverRepository,
  PartnerCompanyRepository,
  RideRepository,
  TimeBucket
}
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.core.application.{EmailSmsService, RideConfirmationData}
import com.shevchyk.core.repository.SentConfirmationRequestRepository
import zio.*
import java.time.{Duration, Instant, LocalDate, ZoneOffset}
import monocle.syntax.all.*
import scala.annotation.nowarn

trait RideService:
  def getRideById(rideId: RideId): IO[RideError, Ride]

  /**
   * Live flight status (gate/terminal/status/time) for a ride, kept fresh by the flight-status monitor. The terminal
   * code drives the airport walk-out buffer. Returns [[None]] when no flight data has been recorded yet.
   */
  def getFlightStatus(rideId: RideId): IO[RideError, Option[FlightStatusRow]]
  def createRide(request: CreateRideRequest): IO[RideError, Ride]
  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]
  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]
  def completeRide(rideId: RideId): IO[RideError, Ride]
  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride]

  def cancelRideWithReason(
      rideId: RideId,
      userId: PersonId,
      userRole: PersonRole,
      request: CancelRideRequest,
      companyId: CompanyId
  ): IO[RideError, Ride]
  def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]]

  def confirmRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]
  def rejectRide(rideId: RideId, driverId: PersonId, reason: String): IO[RideError, Ride]

  def handOffToExternal(
      rideId: RideId,
      callerCompanyId: CompanyId,
      callerId: PersonId,
      req: HandOffRequest
  ): IO[RideError, Ride]

  def createPartnerCompany(companyId: CompanyId, req: CreatePartnerCompanyRequest): IO[RideError, PartnerCompany]
  def listPartnerCompanies(companyId: CompanyId): IO[RideError, List[PartnerCompany]]
  def createExternalDriver(companyId: CompanyId, req: CreateExternalDriverRequest): IO[RideError, ExternalDriver]
  def listExternalDrivers(companyId: CompanyId): IO[RideError, List[ExternalDriver]]

  def updateRideStatus(
      rideId: RideId,
      request: UpdateRideStatusRequest,
      userId: PersonId,
      userRole: PersonRole
  ): IO[RideError, Ride]
  def assignDriver(rideId: RideId, driverId: PersonId, overrideScheduleConflict: Boolean = false): IO[RideError, Ride]
  def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]
  def getRidesByStatusAndCompany(status: RideStatus, companyId: CompanyId): IO[RideError, List[Ride]]
  // Company-scoped: a dispatcher can only list rides of a driver/client within their own
  // tenant. The companyId comes from the caller's JWT, never from the request path.
  def getDriverRides(driverId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]
  def getClientRides(clientId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]
  def getAllRides: IO[RideError, List[Ride]]
  def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]
  def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]]

  def getDriverRidesPaginated(
      driverId: PersonId,
      companyId: CompanyId,
      offset: Int,
      limit: Int
  ): IO[RideError, List[Ride]]

  def updateRideDetails(
      rideId: RideId,
      request: UpdateRideDetailsRequest,
      userId: PersonId,
      userRole: PersonRole,
      companyId: Option[CompanyId]
  ): IO[RideError, Ride]

  /**
   * Hand an Assigned/Confirmed ride to a different driver. A ride whose scheduled pickup time has already passed cannot
   * be reassigned (clock-skew tolerance per [[RidePolicy]]) — except for the emergency-reassignment flow, which sets
   * `allowPastRide = true` because it exists precisely for rides going wrong right now.
   */
  def reassignDriver(
      rideId: RideId,
      newDriverId: PersonId,
      overrideScheduleConflict: Boolean = false,
      allowPastRide: Boolean = false
  ): IO[RideError, Ride]

  def markPayment(
      rideId: RideId,
      paymentStatus: PaymentStatus,
      paymentMethod: Option[PaymentMethod]
  ): IO[RideError, Ride]
  def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]]
  def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]
  def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]
  def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]
  def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]
  def getDailyStats(companyId: CompanyId, days: Int): IO[RideError, List[(String, Int, Int, Int)]]

  def getDriverEarnings(
      driverId: PersonId,
      companyId: CompanyId,
      period: EarningsPeriod,
      anchorDate: java.time.LocalDate
  ): IO[RideError, DriverEarningsReport]

  /**
   * Set the final price on a ride.
   *
   * Authorization: Dispatcher may set price on any company ride; a Driver may set price only on a ride assigned to
   * them. Tenant isolation: companyId comes from JWT, never from the request.
   */
  def setRidePrice(
      rideId: RideId,
      price: Double,
      userId: PersonId,
      userRole: PersonRole,
      companyId: CompanyId
  ): IO[RideError, Ride]

  /**
   * Fetch rides for a list of drivers within a company, optionally filtered to the inclusive date range [from, to]. The
   * `from` and `to` strings must be ISO-8601 date strings (YYYY-MM-DD); a malformed value fails with
   * `RideError.ValidationError` so the route can return HTTP 400.
   *
   * Tenant isolation: each driver's rides are fetched via `getDriverRides` which already scopes by `companyId`, so a
   * foreign `driverId` simply returns an empty list — no data leak.
   */
  def getRidesByDrivers(
      driverIds: List[PersonId],
      from: Option[String],
      to: Option[String],
      companyId: CompanyId
  ): IO[RideError, List[Ride]]

class RideServiceImpl(
    rideRepository: RideRepository,
    personRepository: PersonRepository,
    eventHub: EventHub,
    emailSmsService: EmailSmsService,
    auditService: AuditService,
    blacklistRepository: BlacklistRepository,
    geocodingService: GeocodingService,
    expenseRepository: ExpenseRepository,
    pickupTimeService: PickupTimeService,
    availabilityChecker: DriverAvailabilityChecker,
    scheduleDayLookup: ScheduleDayLookup,
    externalDriverRepo: ExternalDriverRepository,
    partnerCompanyRepo: PartnerCompanyRepository,
    sentConfirmationRequestRepository: SentConfirmationRequestRepository
) extends RideService:

  /**
   * Log the violated rule name and message, then fail with BusinessRuleViolation.
   */
  private def failRule(rule: String, msg: String): IO[RideError, Nothing] =
    ZIO.logWarning(s"assignDriver rejected: rule=$rule msg=$msg") *>
      ZIO.fail(RideError.BusinessRuleViolation(rule, msg))

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideRepository
    .findById(rideId)
    .mapDatabaseError
    .flatMap {
      case Some(ride) => ZIO.succeed(ride)
      case None       => ZIO.fail(RideError.RideNotFound(rideId))
    }

  def getFlightStatus(rideId: RideId): IO[RideError, Option[FlightStatusRow]] =
    rideRepository.findFlightStatus(rideId).mapDatabaseError

  def createRide(request: CreateRideRequest): IO[RideError, Ride] =
    for {
      // Validate pickup is in the future (allow clock-skew tolerance, RidePolicy)
      _               <-
        request.scheduledTime match
          case Some(t) if RidePolicy.isInThePast(t) =>
            ZIO.fail(RideError.ValidationError("Pickup time must be in the future"))
          case _                                    => ZIO.unit
      // Validate addresses differ
      _               <-
        ZIO
          .fail(RideError.ValidationError("Pickup and dropoff addresses must be different"))
          .when(request.pickupLocation.address == request.dropoffLocation.address)
          .unit
      // Company isolation: the ride's client must belong to the same company the ride is created for.
      // companyId comes from the creator's JWT (see RideApi.createRideServer), so this prevents a
      // secretary/dispatcher of company A from creating a ride that references a client of company B.
      clientOpt       <- personRepository.findById(request.clientId).mapDatabaseError
      client          <- ZIO.fromOption(clientOpt).orElseFail(RideError.PersonNotFound(request.clientId))
      _               <-
        ZIO
          .fail(RideError.BusinessRuleViolation("company_isolation", "Client belongs to a different company"))
          .when(!client.companyId.contains(request.companyId))
          .unit
      enrichedPickup  <- geocodingService
                           .enrichLocation(request.pickupLocation)
                           .orElse(ZIO.succeed(request.pickupLocation))
      enrichedDropoff <- geocodingService
                           .enrichLocation(request.dropoffLocation)
                           .orElse(ZIO.succeed(request.dropoffLocation))
      enrichedRequest  = request.copy(pickupLocation = enrichedPickup, dropoffLocation = enrichedDropoff)
      // Auto-compute pickup time for airport departure rides when the operator did NOT supply one.
      // Guard conditions: departure (isArrival=false), no manual pickupDateTime, flightTime present.
      adjustedRequest <-
        enrichedRequest.specifics match
          case Some(RideSpecifics.AirportTransfer(_, _, false)) if enrichedRequest.pickupDateTime.isEmpty =>
            enrichedRequest.scheduledTime match
              case Some(flightDep) =>
                (for {
                  fromLat <- ZIO
                               .fromOption(enrichedPickup.latitude)
                               .orElseFail(PickupTimeService.Error.MissingCoordinates)
                  fromLng <- ZIO
                               .fromOption(enrichedPickup.longitude)
                               .orElseFail(PickupTimeService.Error.MissingCoordinates)
                  toLat   <- ZIO
                               .fromOption(enrichedDropoff.latitude)
                               .orElseFail(PickupTimeService.Error.MissingCoordinates)
                  toLng   <- ZIO
                               .fromOption(enrichedDropoff.longitude)
                               .orElseFail(PickupTimeService.Error.MissingCoordinates)
                  result  <- pickupTimeService.computePickupTime(
                               taxiCompanyId = enrichedRequest.companyId,
                               clientCompanyId = enrichedRequest.clientCompanyId,
                               flightDeparture = flightDep,
                               fromLat = fromLat,
                               fromLng = fromLng,
                               toLat = toLat,
                               toLng = toLng
                             )
                  _       <-
                    ZIO.when(result.travelTimeFallback)(
                      ZIO.logWarning(
                        s"pickup-time: HERE unavailable, used Haversine for ride creation " +
                          s"(company=${enrichedRequest.companyId.value})"
                      )
                    )
                } yield enrichedRequest.copy(pickupDateTime = Some(result.pickupDateTime)))
                  .mapError(e =>
                    RideError.ExternalServiceError(
                      "PickupTimeService",
                      e match
                        case PickupTimeService.Error.SettingsLoadFailed(cause) => cause
                        case PickupTimeService.Error.MissingCoordinates        =>
                          new RuntimeException("Missing geocoded coordinates for pickup-time calculation")
                    )
                  )
                  .orElse(ZIO.succeed(enrichedRequest)) // any error → keep original, don't block ride creation
              case None            =>
                ZIO.logWarning(
                  "Airport departure ride has no flightTime; using supplied pickupDateTime as-is"
                ) *>
                  ZIO.succeed(enrichedRequest)
          case _                                                                                          =>
            // Arrivals, regular rides, or rides with a manual pickup time: pass through unchanged.
            ZIO.succeed(enrichedRequest)
      ride            <- ZIO.succeed(RideMapper.fromRequest(adjustedRequest))
      persistedRide   <- rideRepository.create(ride).mapDatabaseError
      _               <-
        eventHub
          .publish(
            WebSocketEvent.RideCreated(
              rideId = persistedRide.id.value,
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value,
              price = persistedRide.finalPrice.orElse(persistedRide.estimatedPrice)
            )
          )
          .ignore
      _               <-
        emailSmsService
          .sendRideConfirmation(
            RideConfirmationData(
              rideId = persistedRide.id.value.toString,
              bookingReference = persistedRide.bookingReferenceOrId,
              clientName = "Client",
              pickupAddress = persistedRide.pickupLocation.address,
              dropoffAddress = persistedRide.dropoffLocation.address,
              scheduledTime = persistedRide.scheduledTime,
              estimatedPrice = persistedRide.estimatedPrice
            )
          )
          .tapError(e => ZIO.logError(s"Failed to send ride confirmation for ride ${persistedRide.id.value}: $e"))
          .ignore
      _               <-
        auditService
          .log(
            AuditLogEntry.record(
              companyId = persistedRide.companyId,
              actorId = persistedRide.clientId,
              action = AuditAction.RideCreated,
              entityType = "ride",
              entityId = persistedRide.id.value
            )
          )
          .tapError(e => ZIO.logWarning(s"Failed to write audit log: $e"))
          .ignore
    } yield persistedRide

  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]] =
    // A user can be both a client and a driver (multi-role). Run BOTH queries and
    // union the results, de-duplicating by ride id, so no rides are silently dropped.
    rideRepository
      .findByClientId(userId)
      .zipWith(rideRepository.findByDriverId(userId))((clientRides, driverRides) =>
        (clientRides ++ driverRides).distinctBy(_.id)
      )
      .mapError(ex => RideError.DatabaseError(ex))

  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.InProgress))
          .when(!ride.canBeStarted)
          .unit
      // Verify the driver starting the ride is the one assigned
      _    <-
        ZIO
          .fail(RideError.UnauthorizedAccess(driverId, rideId))
          .when(!ride.driverId.contains(driverId))
          .unit

      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(driverId))
      // Company isolation
      _         <-
        ZIO
          .fail(RideError.BusinessRuleViolation("company_isolation", "Driver belongs to a different company"))
          .when(!driver.companyId.contains(ride.companyId))
          .unit

      updatedRide   = ride
                        .focus(_.status)
                        .replace(RideStatus.InProgress)
                        .focus(_.startTime)
                        .replace(Some(Instant.now()))

      // Atomic compare-and-set: only start while the ride is still `Confirmed` (the driver must
      // confirm before starting). Guards against a concurrent cancel/reassign racing this start —
      // the loser gets InvalidStatusTransition instead of silently overwriting the winner.
      applied      <- rideRepository.updateIfStatus(updatedRide, Set(RideStatus.Confirmed)).mapDatabaseError
      _            <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.InProgress)).when(!applied).unit
      persistedRide = updatedRide
    } yield persistedRide

  def confirmRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for {
      ride      <- getRideById(rideId)
      _         <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Confirmed))
          .when(!ride.canBeConfirmed)
          .unit
      // Verify the driver confirming is the one assigned to this ride.
      _         <-
        ZIO
          .fail(RideError.UnauthorizedAccess(driverId, rideId))
          .when(!ride.driverId.contains(driverId))
          .unit
      // Company isolation: the driver must belong to the ride's company.
      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(driverId))
      _         <-
        ZIO
          .fail(RideError.BusinessRuleViolation("company_isolation", "Driver belongs to a different company"))
          .when(!driver.companyId.contains(ride.companyId))
          .unit

      updatedRide = ride
                      .focus(_.status)
                      .replace(RideStatus.Confirmed)
                      .focus(_.confirmedAt)
                      .replace(Some(Instant.now()))

      applied      <- rideRepository.updateIfStatus(updatedRide, Set(RideStatus.Assigned)).mapDatabaseError
      _            <-
        ZIO
          .fail(RideError.InvalidStatusTransition(RideStatus.Assigned, RideStatus.Confirmed))
          .when(!applied)
          .unit
      persistedRide = updatedRide
      // Clear dedup so a re-assigned ride can receive a new confirmation request.
      _            <- sentConfirmationRequestRepository.clear(rideId).ignore
      _            <-
        eventHub
          .publish(
            WebSocketEvent.RideConfirmed(
              rideId = persistedRide.id.value,
              driverId = driverId.value,
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _            <-
        auditService
          .log(
            AuditLogEntry.record(
              companyId = persistedRide.companyId,
              actorId = driverId,
              action = AuditAction.RideStatusChanged,
              entityType = "ride",
              entityId = persistedRide.id.value,
              oldValue = Some(ride.status.toString),
              newValue = Some(RideStatus.Confirmed.toString)
            )
          )
          .tapError(e => ZIO.logWarning(s"Failed to write audit log for ride confirmation: $e"))
          .ignore
    } yield persistedRide

  def rejectRide(rideId: RideId, driverId: PersonId, reason: String): IO[RideError, Ride] =
    for {
      ride      <- getRideById(rideId)
      _         <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Requested))
          .when(!ride.canBeRejected)
          .unit
      // Verify the driver rejecting is the one assigned.
      _         <-
        ZIO
          .fail(RideError.UnauthorizedAccess(driverId, rideId))
          .when(!ride.driverId.contains(driverId))
          .unit
      // Rejection reason must not be empty.
      _         <-
        ZIO
          .fail(RideError.RejectionReasonRequired(rideId))
          .when(reason.trim.isEmpty)
          .unit
      // Company isolation.
      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(driverId))
      _         <-
        ZIO
          .fail(RideError.BusinessRuleViolation("company_isolation", "Driver belongs to a different company"))
          .when(!driver.companyId.contains(ride.companyId))
          .unit

      now         = Instant.now()
      updatedRide = ride
                      .focus(_.status)
                      .replace(RideStatus.Requested)
                      .focus(_.driverId)
                      .replace(None)
                      .focus(_.rejectionReason)
                      .replace(Some(reason))
                      .focus(_.rejectedBy)
                      .replace(Some(driverId))
                      .focus(_.rejectedAt)
                      .replace(Some(now))
                      .focus(_.confirmedAt)
                      .replace(None)

      applied      <-
        rideRepository
          .updateIfStatus(updatedRide, Set(RideStatus.Assigned, RideStatus.Confirmed))
          .mapDatabaseError
      _            <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Requested))
          .when(!applied)
          .unit
      persistedRide = updatedRide
      // Clear dedup for both confirmations and reminders so a re-assigned ride starts fresh.
      _            <- sentConfirmationRequestRepository.clear(rideId).ignore
      _            <- rideRepository.clearReminders(rideId).mapDatabaseError
      _            <-
        eventHub
          .publish(
            WebSocketEvent.RideRejected(
              rideId = persistedRide.id.value,
              driverId = driverId.value,
              clientId = persistedRide.clientId.value,
              reason = reason,
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _            <-
        auditService
          .log(
            AuditLogEntry.record(
              companyId = persistedRide.companyId,
              actorId = driverId,
              action = AuditAction.RideStatusChanged,
              entityType = "ride",
              entityId = persistedRide.id.value,
              oldValue = Some(ride.status.toString),
              newValue = Some(s"Requested (rejected: $reason)")
            )
          )
          .tapError(e => ZIO.logWarning(s"Failed to write audit log for ride rejection: $e"))
          .ignore
    } yield persistedRide

  def completeRide(rideId: RideId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <-
        ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Completed)).when(!ride.canBeCompleted).unit

      updatedRide   = ride
                        .focus(_.status)
                        .replace(RideStatus.Completed)
                        .focus(_.endTime)
                        .replace(Some(Instant.now()))

      // Atomic compare-and-set: only complete while the ride is still `InProgress`. Guards against
      // a concurrent cancel racing this completion — the loser gets InvalidStatusTransition instead
      // of silently overwriting the winner.
      applied      <- rideRepository.updateIfStatus(updatedRide, Set(RideStatus.InProgress)).mapDatabaseError
      _            <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Completed)).when(!applied).unit
      persistedRide = updatedRide
    } yield persistedRide

  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Cancelled))
          .when(ride.status == RideStatus.Cancelled)
          .unit
      _    <- ZIO.fail(RideError.UnauthorizedAccess(userId, rideId)).when(ride.status == RideStatus.Completed).unit
      // Ownership: client can only cancel own rides, driver only assigned rides, dispatcher can cancel any
      _    <- validateCancelPermission(ride, userId, userRole)

      updatedRide   = ride.focus(_.status).replace(RideStatus.Cancelled)
      // Atomic compare-and-set: only cancel from a still-cancellable status. Guards against a
      // concurrent start/complete/reassign racing this cancel — the loser gets
      // InvalidStatusTransition instead of silently overwriting the winner.
      applied      <-
        rideRepository
          .updateIfStatus(
            updatedRide,
            Set(
              RideStatus.Requested,
              RideStatus.Assigned,
              RideStatus.Confirmed,
              RideStatus.InProgress,
              RideStatus.HandedOff
            )
          )
          .mapDatabaseError
      _            <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Cancelled)).when(!applied).unit
      persistedRide = updatedRide
    } yield persistedRide

  def cancelRideWithReason(
      rideId: RideId,
      userId: PersonId,
      userRole: PersonRole,
      request: CancelRideRequest,
      companyId: CompanyId
  ): IO[RideError, Ride] =
    for {
      ride         <- getRideById(rideId)
      // Tenant isolation: a dispatcher from company A must not cancel a ride of company B.
      _            <- ZIO.fail(RideError.UnauthorizedAccess(userId, rideId)).when(ride.companyId != companyId).unit
      _            <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Cancelled))
          .when(ride.status == RideStatus.Cancelled)
          .unit
      _            <- ZIO.fail(RideError.UnauthorizedAccess(userId, rideId)).when(ride.status == RideStatus.Completed).unit
      // Ownership: client can only cancel own rides, driver only assigned rides, dispatcher can cancel any
      _            <- validateCancelPermission(ride, userId, userRole)
      // The reason must be a known value and one this role is allowed to state. Defense-in-depth: the
      // Flutter dialog already hides staff-only reasons from clients, but a forged request must be
      // rejected here too (e.g. a client cannot cancel citing client_no_show or driver_unavailable).
      reason       <- ZIO
                        .fromOption(CancellationReason.fromString(request.reason))
                        .orElseFail(RideError.ValidationError(s"Unknown cancellation reason: ${request.reason}"))
      _            <-
        ZIO
          .fail(
            RideError.ValidationError(s"Cancellation reason '${request.reason}' is not allowed for this role")
          )
          .when(!CancellationReason.allowedFor(reason, userRole))
          .unit
      // A cancellation fee charges the client; a negative value would credit them instead.
      // Guard here too (not only at the HTTP validator) so direct callers can't bypass it.
      _            <-
        ZIO
          .fail(RideError.ValidationError("Cancellation fee cannot be negative"))
          .when(request.fee.exists(_ < 0))
          .unit

      // Persist the canonical wire form so statistics group cleanly regardless of input casing.
      updatedRide   = ride
                        .focus(_.status)
                        .replace(RideStatus.Cancelled)
                        .focus(_.cancellationReason)
                        .replace(Some(CancellationReason.toWire(reason)))
                        .focus(_.cancellationFee)
                        .replace(request.fee)
                        .focus(_.cancelledBy)
                        .replace(Some(userId))
      // Atomic compare-and-set: only cancel from a still-cancellable status. Guards against a
      // concurrent start/complete/reassign racing this cancel — the loser gets
      // InvalidStatusTransition instead of silently overwriting the winner.
      // HandedOff is included so a ride that was handed off to an external driver can still
      // be cancelled (e.g. if the external driver also falls through).
      applied      <-
        rideRepository
          .updateIfStatus(
            updatedRide,
            Set(
              RideStatus.Requested,
              RideStatus.Assigned,
              RideStatus.Confirmed,
              RideStatus.InProgress,
              RideStatus.HandedOff
            )
          )
          .mapDatabaseError
      _            <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Cancelled)).when(!applied).unit
      persistedRide = updatedRide
      // Side-effects only fire once the cancel actually applied, so we never emit a
      // RideStatusChanged/audit entry for a cancellation that lost the race.
      _            <-
        eventHub
          .publish(
            WebSocketEvent.RideStatusChanged(
              rideId = persistedRide.id.value,
              newStatus = "Cancelled",
              driverId = persistedRide.driverId.map(_.value),
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value,
              cancellationReason = Some(request.reason)
            )
          )
          .ignore
      _            <-
        auditService
          .log(
            AuditLogEntry.record(
              companyId = persistedRide.companyId,
              actorId = userId,
              action = AuditAction.RideCancelled,
              entityType = "ride",
              entityId = persistedRide.id.value,
              newValue = Some(s"reason=${request.reason}")
            )
          )
          .tapError(e => ZIO.logWarning(s"Failed to write audit log: $e"))
          .ignore
    } yield persistedRide

  def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]] =
    for {
      companyRides <- rideRepository.findByCompanyId(companyId).mapDatabaseError
      cancelled     = companyRides.filter(_.status == RideStatus.Cancelled)
      stats         = cancelled.groupBy(_.cancellationReason.getOrElse("unknown")).map((k, v) => k -> v.size)
    } yield stats

  def updateRideStatus(
      rideId: RideId,
      request: UpdateRideStatusRequest,
      userId: PersonId,
      userRole: PersonRole
  ): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)

      // Authorization: driver can only update own rides, dispatcher can update any
      _               <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(userRole == PersonRole.Driver && !ride.driverId.contains(userId))
          .unit
      _               <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(userRole != PersonRole.Driver && userRole != PersonRole.Dispatcher)
          .unit

      // Validate transition.
      // Dispatchers may override the confirmation gate and move Assigned -> InProgress directly.
      // Drivers must always go through Confirmed first.
      _               <-
        request.status match
          case RideStatus.InProgress =>
            val dispatcherOverride =
              userRole == PersonRole.Dispatcher &&
                (ride.status == RideStatus.Assigned || ride.status == RideStatus.Confirmed) &&
                ride.driverId.isDefined
            ZIO
              .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.InProgress))
              .when(!ride.canBeStarted && !dispatcherOverride)
              .unit
          case RideStatus.Completed  =>
            ZIO
              .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Completed))
              .when(!ride.canBeCompleted)
              .unit
          case RideStatus.Cancelled  =>
            ZIO
              .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Cancelled))
              .when(!ride.canBeCancelled)
              .unit
          case RideStatus.Confirmed  =>
            // A driver may confirm via updateRideStatus as well (same as confirmRide).
            ZIO
              .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Confirmed))
              .when(!ride.canBeConfirmed)
              .unit
          case target                => ZIO.fail(RideError.InvalidStatusTransition(ride.status, target))

      // Statuses the ride must still be in for this transition to apply. Mirrors the per-target
      // guards above so the atomic CAS rejects exactly the transitions the in-memory checks would.
      // The `case _` arm is unreachable: any other target already failed via `case target =>`
      // above. It maps to the *full* status set (never an empty set) so that, even if a future
      // refactor lets it through, the CAS still guards on a status rather than silently degrading
      // to "always apply" (an empty set becomes `WHERE ... AND TRUE` in updateIfStatus).
      expectedStatuses =
        request.status match
          // Assigned is accepted alongside Confirmed so a dispatcher may override the
          // confirm-before-start rule (Assigned -> InProgress); a driver still needs Confirmed.
          case RideStatus.InProgress => Set(RideStatus.Assigned, RideStatus.Confirmed)
          case RideStatus.Completed  => Set(RideStatus.InProgress)
          case RideStatus.Confirmed  => Set(RideStatus.Assigned)
          case RideStatus.Cancelled  =>
            Set(
              RideStatus.Requested,
              RideStatus.Assigned,
              RideStatus.Confirmed,
              RideStatus.InProgress,
              RideStatus.HandedOff
            )
          case _                     => RideStatus.values.toSet

      updatedRide   = ride
                        .focus(_.status)
                        .replace(request.status)
                        .focus(_.notes)
                        .replace(request.notes.orElse(ride.notes))
                        .focus(_.startTime)
                        .replace(if request.status == RideStatus.InProgress then Some(Instant.now()) else ride.startTime)
                        .focus(_.endTime)
                        .replace(if request.status == RideStatus.Completed then Some(Instant.now()) else ride.endTime)

      // Atomic compare-and-set: only transition while the ride is still in an expected status.
      // Guards against a concurrent transition racing this one — the loser gets
      // InvalidStatusTransition instead of silently overwriting the winner.
      applied      <- rideRepository.updateIfStatus(updatedRide, expectedStatuses).mapDatabaseError
      _            <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, request.status)).when(!applied).unit
      persistedRide = updatedRide
      // Side-effects only fire once the transition actually applied, so we never emit a
      // RideStatusChanged/audit entry for a transition that lost the race.
      _            <-
        eventHub
          .publish(
            WebSocketEvent.RideStatusChanged(
              rideId = persistedRide.id.value,
              newStatus = persistedRide.status.toString,
              driverId = persistedRide.driverId.map(_.value),
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _            <-
        auditService
          .log(
            AuditLogEntry.record(
              companyId = persistedRide.companyId,
              actorId = userId,
              action = AuditAction.RideStatusChanged,
              entityType = "ride",
              entityId = persistedRide.id.value,
              oldValue = Some(ride.status.toString),
              newValue = Some(persistedRide.status.toString)
            )
          )
          .tapError(e => ZIO.logWarning(s"Failed to write audit log for status change: $e"))
          .ignore
    } yield persistedRide

  def updateRideDetails(
      rideId: RideId,
      request: UpdateRideDetailsRequest,
      userId: PersonId,
      userRole: PersonRole,
      companyId: Option[CompanyId]
  ): IO[RideError, Ride] =
    for {
      ride        <- getRideById(rideId)
      _           <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, ride.status)).when(!ride.canBeEdited).unit
      _           <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(ride.creatorId != userId && userRole != PersonRole.Dispatcher)
          .unit
      // Company isolation: the ride must belong to the caller's company. A missing
      // companyId is treated as a failure (not a bypass) so a caller can never skip the
      // check by omitting it — the HTTP layer always supplies it via requireCompanyId.
      _           <-
        companyId match
          case Some(cid) => ZIO.fail(RideError.UnauthorizedAccess(userId, rideId)).when(ride.companyId != cid).unit
          case None      => ZIO.fail(RideError.UnauthorizedAccess(userId, rideId))

      // Reassigning the ride to another client is dispatcher-only (a client-creator must not
      // move their ride onto someone else) and follows the same company-isolation rule as
      // createRide: the new client must exist and belong to the ride's company.
      newClientId <-
        request.clientId.filter(_ != ride.clientId) match
          case None              => ZIO.none
          case Some(newClientId) =>
            for {
              _         <-
                ZIO
                  .fail(RideError.UnauthorizedAccess(userId, rideId))
                  .when(userRole != PersonRole.Dispatcher)
                  .unit
              clientOpt <- personRepository.findById(newClientId).mapDatabaseError
              client    <- ZIO.fromOption(clientOpt).orElseFail(RideError.PersonNotFound(newClientId))
              _         <-
                ZIO
                  .fail(
                    RideError.BusinessRuleViolation("company_isolation", "Client belongs to a different company")
                  )
                  .when(!client.companyId.contains(ride.companyId))
                  .unit
            } yield Some(newClientId)

      newPickup  <-
        ZIO.foreach(request.pickupLocation)(loc =>
          geocodingService.enrichLocation(loc).orElse(ZIO.succeed[Location](loc))
        )
      newDropoff <-
        ZIO.foreach(request.dropoffLocation)(loc =>
          geocodingService.enrichLocation(loc).orElse(ZIO.succeed[Location](loc))
        )
      updatedRide = ride
                      .focus(_.clientId)
                      .replace(newClientId.getOrElse(ride.clientId))
                      .focus(_.pickupLocation)
                      .replace(newPickup.getOrElse(ride.pickupLocation))
                      .focus(_.dropoffLocation)
                      .replace(newDropoff.getOrElse(ride.dropoffLocation))
                      .focus(_.pickupDateTime)
                      .replace(request.pickupDateTime.getOrElse(ride.pickupDateTime))
                      .focus(_.scheduledTime)
                      .replace(request.scheduledTime.orElse(ride.scheduledTime))
                      .focus(_.notes)
                      .replace(request.notes.orElse(ride.notes))
                      .focus(_.specifics)
                      .replace(mergeSpecifics(request.specifics, ride.specifics))
                      .focus(_.specialRequirements)
                      .replace(request.specialRequirements.orElse(ride.specialRequirements))
                      // None leaves tags unchanged; Some(list) replaces (already normalized in the DTO layer).
                      .focus(_.tags)
                      .replace(request.tags.getOrElse(ride.tags))

      persistedRide    <- rideRepository.update(updatedRide).mapDatabaseError
      pickupTimeChanged = request.pickupDateTime.exists(_ != ride.pickupDateTime)
      _                <- ZIO.when(pickupTimeChanged)(rideRepository.clearReminders(rideId).mapDatabaseError)
      _                <-
        eventHub
          .publish(
            WebSocketEvent.RideDetailsUpdated(
              rideId = persistedRide.id.value,
              driverId = persistedRide.driverId.map(_.value),
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value,
              // Only set when this update actually moved the ride to another client, so
              // consumers can tell a reassignment apart from an ordinary details edit.
              previousClientId = newClientId.map(_ => ride.clientId.value)
            )
          )
          .ignore
    } yield persistedRide

  /**
   * Merge a three-valued specifics update into the ride's existing specifics.
   *
   *   - Unchanged → keep the ride's current specifics (the partial update did not touch airportness).
   *   - Clear → drop the specifics (the ride is no longer an airport transfer).
   *   - Set → the DTO builds a placeholder `AirportTransfer("UNKNOWN", flight, isArrival = false)` carrying the
   *     optional flight number. When the ride is already an airport transfer we keep its `airportCode` and `isArrival`,
   *     replacing only the (optional) flight number — editing it must never flip the direction or wipe the airport
   *     code. A None flight is valid: an airport transfer whose flight is not yet known.
   */
  private def mergeSpecifics(
      incoming: FieldUpdate[RideSpecifics],
      existing: Option[RideSpecifics]
  ): Option[RideSpecifics] =
    incoming match
      case FieldUpdate.Unchanged                                        => existing
      case FieldUpdate.Clear                                            => None
      case FieldUpdate.Set(RideSpecifics.AirportTransfer(_, flight, _)) =>
        existing match
          case Some(prev: RideSpecifics.AirportTransfer) => Some(prev.copy(flightNumber = flight))
          case _                                         => Some(RideSpecifics.AirportTransfer("UNKNOWN", flight))

  def assignDriver(
      rideId: RideId,
      driverId: PersonId,
      overrideScheduleConflict: Boolean = false
  ): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      // A non-Requested ride was already taken (typically by another dispatcher) since the caller's
      // view was loaded. Report it as RideAlreadyAssigned (409 "Ride already assigned") instead of a
      // misleading InvalidStatusTransition(Assigned, Assigned) — the client should reload, not retry.
      _    <-
        ZIO
          .fail(RideError.RideAlreadyAssigned(rideId, ride.driverId.getOrElse(driverId)))
          .when(!ride.canBeAssigned)
          .unit

      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(driverId))

      _ <- failRule("driver_role", "Person is not a driver").when(!driver.canDrive).unit
      _ <-
        failRule("company_isolation", "Driver belongs to a different company")
          .when(!driver.companyId.contains(ride.companyId))
          .unit

      // Constraint #3: an assignment must reference a valid ScheduleDay. Only enforced when the
      // ride carries a scheduleDayId — rides without one keep the previous behaviour.
      _ <- validateScheduleDay(ride, driverId)

      // Check blacklist
      blocked <- blacklistRepository.isBlacklisted(ride.clientId, driverId).mapDatabaseError
      _       <- failRule("blacklist", "This driver is blacklisted for the ride's client").when(blocked).unit

      // Check scheduling conflicts (ride-vs-ride + unavailability windows).
      // A dispatcher can knowingly override the conflict; tenant/role/blacklist checks above still apply.
      _ <- checkScheduleConflict(driverId, ride).unless(overrideScheduleConflict)

      // Check VIP and preferred driver
      clientOpt        <- personRepository.findById(ride.clientId).mapDatabaseError
      isVip             = clientOpt.exists(_.isVip)
      isPreferredDriver = clientOpt.flatMap(_.preferredDriverId).contains(driverId)

      updatedRide   = ride
                        .focus(_.status)
                        .replace(RideStatus.Assigned)
                        .focus(_.driverId)
                        .replace(Some(driverId))
                        .focus(_.isVipRide)
                        .replace(isVip)
                        .focus(_.preferredDriverUsed)
                        .replace(isPreferredDriver)

      // Atomic compare-and-set: only assign if the ride is still `Requested`. Guards against
      // two dispatchers assigning different drivers to the same ride concurrently — the loser
      // gets an InvalidStatusTransition instead of silently overwriting the winner.
      applied      <- rideRepository.updateIfStatus(updatedRide, Set(RideStatus.Requested)).mapDatabaseError
      // The CAS lost: another assignment moved the ride out of Requested between our read and write.
      // Surface RideAlreadyAssigned (409 "Ride already assigned") so the loser reloads rather than
      // retrying a doomed transition. Report the WINNER's driver — re-read the ride so the error
      // carries the driver that actually holds the ride, not this losing attempt's driverId.
      _            <-
        ZIO
          .when(!applied) {
            rideRepository
              .findById(rideId)
              .mapDatabaseError
              .map(_.flatMap(_.driverId).getOrElse(driverId))
              .flatMap(winner => ZIO.fail(RideError.RideAlreadyAssigned(rideId, winner)))
          }
          .unit
      persistedRide = updatedRide
      _            <-
        eventHub
          .publish(
            WebSocketEvent.RideAssigned(
              rideId = persistedRide.id.value,
              driverId = driverId.value,
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value,
              price = persistedRide.finalPrice.orElse(persistedRide.estimatedPrice)
            )
          )
          .ignore
      _            <-
        emailSmsService
          .sendDriverAssignment(
            RideConfirmationData(
              rideId = persistedRide.id.value.toString,
              bookingReference = persistedRide.bookingReferenceOrId,
              clientName = "Client",
              pickupAddress = persistedRide.pickupLocation.address,
              dropoffAddress = persistedRide.dropoffLocation.address,
              scheduledTime = persistedRide.scheduledTime,
              driverName = Some(driver.name)
            )
          )
          .tapError(e =>
            ZIO.logError(s"Failed to send driver assignment notification for ride ${persistedRide.id.value}: $e")
          )
          .ignore
      _            <-
        auditService
          .log(
            AuditLogEntry.record(
              companyId = persistedRide.companyId,
              actorId = driverId,
              action = AuditAction.RideAssigned,
              entityType = "ride",
              entityId = persistedRide.id.value,
              newValue = Some(s"driverId=${driverId.value}")
            )
          )
          .tapError(e => ZIO.logWarning(s"Failed to write audit log for ride assignment: $e"))
          .ignore
    } yield persistedRide

  def reassignDriver(
      rideId: RideId,
      newDriverId: PersonId,
      overrideScheduleConflict: Boolean = false,
      allowPastRide: Boolean = false
  ): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <-
        ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Assigned)).when(!ride.canBeReassigned).unit

      // A ride whose pickup time has already passed must not be handed to a new driver — reassignment only makes
      // sense for rides still ahead. The emergency-reassignment flow bypasses this (allowPastRide = true): it exists
      // precisely for a ride going wrong right now, i.e. at/after its pickup time. ASAP rides (no scheduledTime)
      // stay reassignable.
      _    <-
        failRule("past_ride", "A ride scheduled in the past cannot be reassigned")
          .when(!allowPastRide && ride.scheduledTime.exists(RidePolicy.isInThePast(_)))
          .unit

      driverOpt <- personRepository.findById(newDriverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(newDriverId))

      _       <- failRule("driver_role", "Person is not a driver").when(!driver.canDrive).unit
      _       <-
        failRule("company_isolation", "Driver belongs to a different company")
          .when(!driver.companyId.contains(ride.companyId))
          .unit

      // Check blacklist
      blocked <- blacklistRepository.isBlacklisted(ride.clientId, newDriverId).mapDatabaseError
      _       <- failRule("blacklist", "This driver is blacklisted for the ride's client").when(blocked).unit

      // Check scheduling conflicts (exclude current ride from conflict check).
      // A dispatcher can knowingly override the conflict; tenant/role/blacklist checks above still apply.
      _ <- checkScheduleConflict(newDriverId, ride).unless(overrideScheduleConflict)

      // Reset confirmation state when the driver changes so the new driver must confirm afresh.
      updatedRide   = ride
                        .focus(_.driverId)
                        .replace(Some(newDriverId))
                        .focus(_.status)
                        .replace(RideStatus.Assigned)
                        .focus(_.confirmedAt)
                        .replace(None)
                        .focus(_.rejectionReason)
                        .replace(None)
                        .focus(_.rejectedBy)
                        .replace(None)
                        .focus(_.rejectedAt)
                        .replace(None)

      // Atomic compare-and-set: only reassign while the ride is still `Assigned` or `Confirmed`.
      applied      <-
        rideRepository
          .updateIfStatus(updatedRide, Set(RideStatus.Assigned, RideStatus.Confirmed))
          .mapDatabaseError
      _            <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Assigned))
          .when(!applied)
          .unit
      persistedRide = updatedRide
      // Clear confirmation dedup so the new driver receives a confirmation request.
      _            <- sentConfirmationRequestRepository.clear(rideId).ignore
      _            <-
        eventHub
          .publish(
            WebSocketEvent.RideAssigned(
              rideId = persistedRide.id.value,
              driverId = newDriverId.value,
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value,
              price = persistedRide.finalPrice.orElse(persistedRide.estimatedPrice)
            )
          )
          .ignore
      _            <-
        auditService
          .log(
            AuditLogEntry.record(
              companyId = persistedRide.companyId,
              actorId = newDriverId,
              action = AuditAction.RideReassigned,
              entityType = "ride",
              entityId = persistedRide.id.value,
              oldValue = ride.driverId.map(d => s"driverId=${d.value}"),
              newValue = Some(s"driverId=${newDriverId.value}")
            )
          )
          .tapError(e => ZIO.logWarning(s"Failed to write audit log for ride reassignment: $e"))
          .ignore
    } yield persistedRide

  def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]] =
    rideRepository.findByStatus(status).mapDatabaseError

  def getRidesByStatusAndCompany(status: RideStatus, companyId: CompanyId): IO[RideError, List[Ride]] =
    rideRepository.findByStatusAndCompany(status, companyId).mapDatabaseError

  def getDriverRides(driverId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]] =
    rideRepository.findByDriverIdAndCompany(driverId, companyId).mapDatabaseError

  def getClientRides(clientId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]] =
    rideRepository.findByClientIdAndCompany(clientId, companyId).mapDatabaseError

  def getAllRides: IO[RideError, List[Ride]] = rideRepository.findAll().mapDatabaseError

  def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]] =
    rideRepository.findByCompanyId(companyId).mapDatabaseError

  def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]] =
    rideRepository
      .findByCompanyIdPaginated(companyId, offset, limit)
      .mapDatabaseError

  def getDriverRidesPaginated(
      driverId: PersonId,
      companyId: CompanyId,
      offset: Int,
      limit: Int
  ): IO[RideError, List[Ride]] =
    rideRepository
      .findByDriverIdAndCompanyPaginated(driverId, companyId, offset, limit)
      .mapDatabaseError

  def markPayment(
      rideId: RideId,
      paymentStatus: PaymentStatus,
      paymentMethod: Option[PaymentMethod]
  ): IO[RideError, Ride] =
    for {
      ride          <- getRideById(rideId)
      // A ride can only be paid for once it has actually been delivered.
      _             <-
        ZIO
          .fail(RideError.BusinessRuleViolation("payment_status", "Only a completed ride can be marked paid"))
          .when(paymentStatus == PaymentStatus.Paid && ride.status != RideStatus.Completed)
          .unit
      // Marking a ride `Paid` is the only payment transition that carries a money-handling race: two
      // concurrent markPayment(Paid) calls on the same Completed ride would lost-update each other's
      // payment_method/paid_at through a read-modify-write `update`. Close it with a field-level CAS
      // (`markPaidIfCompleted`) that flips only the payment columns, atomically, and only while the
      // row is still Completed and not already Paid. Other payment statuses (Pending/Unpaid) are legal
      // in any ride status and carry no money risk, so they take the plain read-modify-write update.
      persistedRide <-
        if paymentStatus == PaymentStatus.Paid then
          // Carry over the existing method when the caller passes none, matching the historic
          // read-modify-write semantics (`paymentMethod.orElse(ride.paymentMethod)`).
          val effectiveMethod = paymentMethod.orElse(ride.paymentMethod)
          for {
            applied <- rideRepository.markPaidIfCompleted(rideId, effectiveMethod).mapDatabaseError
            result  <-
              if applied then getRideById(rideId)
              else
                // The CAS did not apply: either the ride is already Paid (a concurrent winner / a
                // re-pay) -> return it idempotently without overwriting paid_at/method, or it is not
                // Completed -> reject. Re-read to distinguish the two.
                getRideById(rideId).flatMap { latest =>
                  if latest.paymentStatus == PaymentStatus.Paid then ZIO.succeed(latest)
                  else
                    ZIO.fail(
                      RideError.BusinessRuleViolation("payment_status", "Only a completed ride can be marked paid")
                    )
                }
          } yield result
        else
          val updatedRide = ride
            .focus(_.paymentStatus)
            .replace(paymentStatus)
            .focus(_.paymentMethod)
            .replace(paymentMethod.orElse(ride.paymentMethod))
          rideRepository.update(updatedRide).mapDatabaseError
    } yield persistedRide

  def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]] = rideRepository
    .findByCompanyId(companyId)
    .mapDatabaseError
    .map(_.filter(r => r.status == RideStatus.Completed && r.paymentStatus == PaymentStatus.Unpaid))

  def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]] =
    rideRepository.countByCompanyGroupedByStatus(companyId).mapDatabaseError

  def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal] =
    rideRepository.sumRevenueByCompany(companyId).mapDatabaseError

  def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal] =
    rideRepository.sumTodayRevenueByCompany(companyId).mapDatabaseError

  def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double] =
    rideRepository.avgAssignmentMinutesByCompany(companyId).mapDatabaseError

  def getDailyStats(companyId: CompanyId, days: Int): IO[RideError, List[(String, Int, Int, Int)]] =
    rideRepository.countDailyStatsByCompany(companyId, days).mapDatabaseError

  def getDriverEarnings(
      driverId: PersonId,
      companyId: CompanyId,
      period: EarningsPeriod,
      anchorDate: LocalDate
  ): IO[RideError, DriverEarningsReport] =
    val (from, to, bucket) = earningsWindow(period, anchorDate)
    for {
      earnings   <- rideRepository.earningsByDriver(driverId, companyId, from, to).mapDatabaseError
      rawBuckets <- rideRepository.earningsBucketsByDriver(driverId, companyId, from, to, bucket).mapDatabaseError
      expenses   <- expenseRepository.sumByDriver(driverId, companyId, from, to).mapDatabaseError
    } yield DriverEarningsReport(
      period = period,
      from = from,
      to = to,
      grossRevenue = earnings.grossRevenue,
      totalExpenses = expenses,
      completedRides = earnings.completedRides,
      cancelledRides = earnings.cancelledRides,
      buckets = rawBuckets.map((start, amount) => EarningsBucket(start, amount))
    )

  def setRidePrice(
      rideId: RideId,
      price: Double,
      userId: PersonId,
      userRole: PersonRole,
      companyId: CompanyId
  ): IO[RideError, Ride] =
    for {
      // Reject negative price (a price of zero is allowed to clear a disputed charge).
      _          <- ZIO.fail(RideError.ValidationError("Price cannot be negative")).when(price < 0).unit
      ride       <- getRideById(rideId)
      // Tenant isolation: the ride must belong to the caller's company.
      _          <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(ride.companyId != companyId)
          .unit
      // Authorization: a Driver may only set price on a ride assigned to them.
      _          <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(userRole == PersonRole.Driver && !ride.driverId.contains(userId))
          .unit
      updatedRide = ride.focus(_.finalPrice).replace(Some(BigDecimal(price)))
      persisted  <- rideRepository.update(updatedRide).mapDatabaseError
    } yield persisted

  def getRidesByDrivers(
      driverIds: List[PersonId],
      from: Option[String],
      to: Option[String],
      companyId: CompanyId
  ): IO[RideError, List[Ride]] =
    for {
      // Validate date strings up-front so a malformed value returns 400, not silent no-filter.
      fromInstantOpt <-
        ZIO
          .foreach(from) { s =>
            ZIO
              .attempt(LocalDate.parse(s).atStartOfDay(ZoneOffset.UTC).toInstant)
              .orElseFail(RideError.ValidationError(s"Invalid date format for 'from': $s"))
          }
      toInstantOpt   <-
        ZIO
          .foreach(to) { s =>
            ZIO
              .attempt(LocalDate.parse(s).plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant)
              .orElseFail(RideError.ValidationError(s"Invalid date format for 'to': $s"))
          }
      // Fetch rides for each driver in parallel; getDriverRides scopes by companyId so a
      // foreign driverId simply returns empty — no data leak.
      allRides       <- ZIO.foreachPar(driverIds)(id => getDriverRides(id, companyId))
      flatRides       = allRides.flatten
      // Apply the optional inclusive date filter (the to-instant is exclusive end-of-day).
      filtered        =
        (fromInstantOpt, toInstantOpt) match
          case (Some(fromI), Some(toI)) =>
            flatRides.filter(r => !r.pickupDateTime.isBefore(fromI) && r.pickupDateTime.isBefore(toI))
          case (Some(fromI), None)      => flatRides.filter(r => !r.pickupDateTime.isBefore(fromI))
          case (None, Some(toI))        => flatRides.filter(r => r.pickupDateTime.isBefore(toI))
          case _                        => flatRides
    } yield filtered

  /**
   * Computes the half-open interval [from, to) and the bucket granularity for the period. All boundaries are in UTC to
   * match date_trunc in SQL.
   */
  private def earningsWindow(period: EarningsPeriod, anchor: LocalDate): (Instant, Instant, TimeBucket) =
    period match
      case EarningsPeriod.Day   =>
        val from = anchor.atStartOfDay(ZoneOffset.UTC).toInstant
        (from, from.plus(Duration.ofDays(1)), TimeBucket.Hour)
      case EarningsPeriod.Week  =>
        val monday = anchor.minusDays((anchor.getDayOfWeek.getValue - 1).toLong)
        val from   = monday.atStartOfDay(ZoneOffset.UTC).toInstant
        (from, from.plus(Duration.ofDays(7)), TimeBucket.Day)
      case EarningsPeriod.Month =>
        val first = anchor.withDayOfMonth(1)
        val from  = first.atStartOfDay(ZoneOffset.UTC).toInstant
        val to    = first.plusMonths(1).atStartOfDay(ZoneOffset.UTC).toInstant
        (from, to, TimeBucket.Day)

  // -- Cancel permission --------------------------------------------------

  // The defensive `case _` below is currently unreachable (the match is exhaustive over PersonRole),
  // but it is kept on purpose so a newly added role fails closed instead of throwing MatchError.
  @nowarn("msg=Unreachable case")
  private def validateCancelPermission(ride: Ride, userId: PersonId, userRole: PersonRole): IO[RideError, Unit] =
    userRole match
      case PersonRole.Dispatcher | PersonRole.Secretary | PersonRole.Admin | PersonRole.ClientSecretary |
          PersonRole.SuperAdmin =>
        ZIO.unit
      case PersonRole.Client =>
        ZIO.fail(RideError.UnauthorizedAccess(userId, ride.id)).when(ride.clientId != userId).unit
      case PersonRole.Driver =>
        ZIO.fail(RideError.UnauthorizedAccess(userId, ride.id)).when(!ride.driverId.contains(userId)).unit
      // Defensive default: any role not explicitly granted cancel rights is denied. Keeps the match
      // exhaustive so a newly added PersonRole fails closed (no cancel) instead of throwing MatchError.
      case _                 => ZIO.fail(RideError.UnauthorizedAccess(userId, ride.id)).unit

  // -- Schedule conflict detection ----------------------------------------

  /**
   * Minimum buffer between rides (travel time + buffer).
   */
  private val MinBufferMinutes = 30L

  /**
   * Default ride duration in minutes when no real ETA is available.
   */
  private val DefaultRideDurationMinutes = 60L

  /**
   * Business constraint #3: an assignment must reference a valid ScheduleDay.
   *
   * When the ride does not carry a `scheduleDayId` this is a no-op (backward compatible). Otherwise the referenced day
   * must:
   *   - exist,
   *   - belong to the ride's company (tenant isolation), and
   *   - be assigned to the very driver being assigned, and
   *   - be active (not cancelled).
   *
   * Tenant comparison uses the ride's `companyId`, never a caller-supplied value.
   */
  private def validateScheduleDay(ride: Ride, driverId: PersonId): IO[RideError, Unit] =
    ride.scheduleDayId match
      case None        => ZIO.unit
      case Some(rawId) =>
        val scheduleDayId = ScheduleDayId(rawId)
        for {
          dayOpt <- scheduleDayLookup.find(scheduleDayId).mapError(ex => RideError.DatabaseError(ex))
          day    <- ZIO
                      .fromOption(dayOpt)
                      .orElse(failRule("schedule_day", s"Schedule day ${rawId} does not exist"))
          _      <-
            failRule("schedule_day", "Schedule day belongs to a different company")
              .when(day.companyId != ride.companyId)
              .unit
          _      <-
            failRule("schedule_day", "Schedule day is assigned to a different driver")
              .when(day.driverId != driverId)
              .unit
          _      <- failRule("schedule_day", "Schedule day is cancelled or inactive").when(!day.active).unit
        } yield ()

  /**
   * Checks whether ``driverId`` has any active ride (Assigned / InProgress) or a manual unavailability window whose
   * time window overlaps with ``candidateRide``.
   *
   * A ride's "occupied window" is: [scheduledTime − buffer, scheduledTime + estimatedDuration + buffer]
   *
   * Without real ETA data we assume a default ride duration of 60 min.
   *
   * CompanyId is taken from the candidate ride — never caller-supplied — to preserve tenant isolation.
   */
  private def checkScheduleConflict(driverId: PersonId, candidateRide: Ride): IO[RideError, Unit] =
    // The real "when the driver is occupied" time is the pickup time, which is
    // always present in pickupDateTime. scheduledTime is only set for airport
    // departures (the flight time) and is None for ordinary rides — falling back
    // to requestTime there compared *request creation* times, so two rides
    // created at about the same moment but on different days collided falsely.
    val candidateTime = candidateRide.pickupDateTime
    val windowSeconds = (DefaultRideDurationMinutes + MinBufferMinutes) * 60
    val windowFrom    = candidateTime.minusSeconds(MinBufferMinutes * 60)
    val windowTo      = candidateTime.plusSeconds(windowSeconds)
    for {
      driverRides      <- rideRepository.findByDriverId(driverId).mapDatabaseError
      activeRides       = driverRides.filter(r =>
                            (r.status == RideStatus.Assigned || r.status == RideStatus.Confirmed ||
                              r.status == RideStatus.InProgress) &&
                              r.id != candidateRide.id // exclude self (relevant for reassign)
                          )
      conflict          = activeRides.find(existing => ridesOverlap(candidateTime, existing.pickupDateTime))
      _                <-
        conflict match
          case Some(conflicting) =>
            // Human-readable fallback message (route + pickup time). The
            // structured fields let the client render a localized dialog with
            // the client name and the dispatcher's local time.
            val msg =
              s"Driver already has a ride from ${conflicting.pickupLocation.address} " +
                s"to ${conflicting.dropoffLocation.address} at ${conflicting.pickupDateTime} " +
                s"— time windows overlap (buffer ${MinBufferMinutes} min)"
            ZIO.logWarning(
              s"assignDriver rejected: rule=schedule_conflict rideId=${conflicting.id.value} msg=$msg"
            ) *>
              ZIO.fail(
                RideError.ScheduleConflict(
                  message = msg,
                  conflictingRideId = Some(conflicting.id),
                  conflictingClientId = Some(conflicting.clientId),
                  conflictingFrom = Some(conflicting.pickupLocation.address),
                  conflictingTo = Some(conflicting.dropoffLocation.address),
                  conflictingPickupAt = Some(conflicting.pickupDateTime)
                )
              )
          case None              => ZIO.unit
      // Check manual unavailability windows (uses the candidateRide's companyId for tenant safety).
      unavailableSlots <- availabilityChecker
                            .overlappingUnavailability(driverId, candidateRide.companyId, windowFrom, windowTo)
                            .mapError(ex => RideError.DatabaseError(ex))
      _                <-
        unavailableSlots.headOption match
          case Some(slot) =>
            val msg = s"Driver has a ${slot.reason} unavailability from ${slot.from} to ${slot.to}"
            ZIO.logWarning(s"assignDriver rejected: rule=schedule_conflict msg=$msg") *>
              ZIO.fail(RideError.ScheduleConflict(msg))
          case None       => ZIO.unit
    } yield ()

  /**
   * Two rides overlap when their time windows intersect.
   *
   * Each ride occupies the window [start, start + defaultDuration + buffer], where `buffer` accounts for travel time to
   * the next pickup location. A conflict exists iff the two windows intersect:
   *   - existingEnd = existingStart + duration + buffer
   *   - candidateEnd = candidateStart + duration + buffer
   *   - overlap iff candidateStart < existingEnd AND existingStart < candidateEnd
   *
   * Examples (duration=60 min, buffer=30 min):
   *   - existing=10:00, candidate=11:31 (91 min gap): existingEnd=11:30, candidateEnd=13:01 → 11:31 < 11:30 = false →
   *     NO overlap (back-to-back rides are allowed)
   *   - existing=10:00, candidate=11:29 (89 min gap): existingEnd=11:30, candidateEnd=13:01 → 11:29 < 11:30 AND 10:00 <
   *     13:01 → OVERLAP (genuine conflict)
   *   - existing=10:00, candidate=10:45 (45 min gap): overlap → conflict
   */
  private def ridesOverlap(candidateTime: Instant, existingTime: Instant): Boolean =
    // Without real ETA data we assume a default ride duration of 60 min for both rides.
    val windowSeconds = (DefaultRideDurationMinutes + MinBufferMinutes) * 60
    val existingEnd   = existingTime.plusSeconds(windowSeconds)
    val candidateEnd  = candidateTime.plusSeconds(windowSeconds)
    // Standard interval overlap: [existingStart, existingEnd) overlaps [candidateStart, candidateEnd) iff:
    candidateTime.isBefore(existingEnd) && existingTime.isBefore(candidateEnd)

  def handOffToExternal(
      rideId: RideId,
      callerCompanyId: CompanyId,
      callerId: PersonId,
      req: HandOffRequest
  ): IO[RideError, Ride] =
    for {
      ride           <- getRideById(rideId)
      // Tenant isolation: the caller must belong to the same company as the ride.
      _              <- ZIO.fail(RideError.UnauthorizedAccess(callerId, rideId)).when(ride.companyId != callerCompanyId).unit
      // Status guard: only a Requested (unassigned) ride can be handed off.
      _              <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.HandedOff))
          .when(!ride.canBeHandedOff)
          .unit
      // Tenant-scoped lookup of external driver — returns None if the driver belongs to another tenant.
      externalDriver <- externalDriverRepo
                          .findById(req.externalDriverId, callerCompanyId)
                          .mapDatabaseError
                          .flatMap(ZIO.fromOption(_).orElseFail(RideError.ExternalDriverNotFound(req.externalDriverId)))
      // Tenant-scoped lookup of partner company.
      partnerCompany <- partnerCompanyRepo
                          .findById(req.partnerCompanyId, callerCompanyId)
                          .mapDatabaseError
                          .flatMap(ZIO.fromOption(_).orElseFail(RideError.PartnerCompanyNotFound(req.partnerCompanyId)))
      updatedRide     = ride
                          .focus(_.status)
                          .replace(RideStatus.HandedOff)
                          .focus(_.externalDriverId)
                          .replace(Some(externalDriver.id))
                          .focus(_.partnerCompanyId)
                          .replace(Some(partnerCompany.id))
      // Atomic CAS: only transition from Requested. Guards against concurrent assignment.
      applied        <-
        rideRepository
          .updateIfStatus(updatedRide, Set(RideStatus.Requested))
          .mapDatabaseError
      _              <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.HandedOff)).when(!applied).unit
      persistedRide   = updatedRide
      _              <-
        eventHub
          .publish(
            WebSocketEvent.RideStatusChanged(
              rideId = persistedRide.id.value,
              newStatus = "HandedOff",
              driverId = None,
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _              <-
        auditService
          .log(
            AuditLogEntry.record(
              companyId = persistedRide.companyId,
              actorId = callerId,
              action = AuditAction.RideHandedOff,
              entityType = "ride",
              entityId = persistedRide.id.value,
              newValue = Some(
                s"externalDriverId=${externalDriver.id.value},partnerCompanyId=${partnerCompany.id.value}"
              )
            )
          )
          .tapError(e => ZIO.logWarning(s"Failed to write audit log for ride handoff: $e"))
          .ignore
    } yield persistedRide

  def createPartnerCompany(companyId: CompanyId, req: CreatePartnerCompanyRequest): IO[RideError, PartnerCompany] =
    val pc = PartnerCompany(
      id = PartnerCompanyId.generate(),
      name = req.name,
      email = req.email,
      phone = req.phone,
      address = req.address,
      taxiCompanyId = companyId,
      createdAt = java.time.Instant.now(),
      updatedAt = java.time.Instant.now()
    )
    partnerCompanyRepo.create(pc).mapDatabaseError

  def listPartnerCompanies(companyId: CompanyId): IO[RideError, List[PartnerCompany]] =
    partnerCompanyRepo.findByCompany(companyId).mapDatabaseError

  def createExternalDriver(companyId: CompanyId, req: CreateExternalDriverRequest): IO[RideError, ExternalDriver] =
    val ed = ExternalDriver(
      id = ExternalDriverId.generate(),
      name = req.name,
      phone = req.phone,
      partnerCompanyId = req.partnerCompanyId,
      taxiCompanyId = companyId,
      createdAt = java.time.Instant.now(),
      updatedAt = java.time.Instant.now()
    )
    externalDriverRepo.create(ed).mapDatabaseError

  def listExternalDrivers(companyId: CompanyId): IO[RideError, List[ExternalDriver]] =
    externalDriverRepo.findByCompany(companyId).mapDatabaseError

object RideService:

  val layer: ZLayer[
    RideRepository & PersonRepository & EventHub & EmailSmsService & AuditService & BlacklistRepository & GeocodingService & ExpenseRepository & PickupTimeService & DriverAvailabilityChecker & ScheduleDayLookup & ExternalDriverRepository & PartnerCompanyRepository & SentConfirmationRequestRepository,
    Nothing,
    RideService
  ] = ZLayer.fromFunction(
    RideServiceImpl.apply
  )
