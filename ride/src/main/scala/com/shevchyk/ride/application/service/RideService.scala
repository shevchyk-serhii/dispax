package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{DriverAvailabilityChecker, EventHub, AuditService, GeocodingService}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.domain.RepositoryExtensions.*
import com.shevchyk.ride.repository.{ExpenseRepository, RideRepository, TimeBucket}
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.core.application.{EmailSmsService, RideConfirmationData}
import zio.*
import java.time.{Duration, Instant, LocalDate, ZoneOffset}
import monocle.syntax.all.*

trait RideService:
  def getRideById(rideId: RideId): IO[RideError, Ride]
  def createRide(request: CreateRideRequest): IO[RideError, Ride]
  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]
  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]
  def completeRide(rideId: RideId): IO[RideError, Ride]
  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride]

  def cancelRideWithReason(
      rideId: RideId,
      userId: PersonId,
      userRole: PersonRole,
      request: CancelRideRequest
  ): IO[RideError, Ride]
  def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]]

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

  def reassignDriver(
      rideId: RideId,
      newDriverId: PersonId,
      overrideScheduleConflict: Boolean = false
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
    availabilityChecker: DriverAvailabilityChecker
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
      ride            <- ZIO.succeed(RideMapper.fromRequest(enrichedRequest))
      persistedRide   <- rideRepository.create(ride).mapDatabaseError
      _               <-
        eventHub
          .publish(
            WebSocketEvent.RideCreated(
              rideId = persistedRide.id.value,
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _               <-
        emailSmsService
          .sendRideConfirmation(
            RideConfirmationData(
              rideId = persistedRide.id.value.toString,
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

  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]] = rideRepository
    .findByClientId(userId)
    .orElse(rideRepository.findByDriverId(userId))
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

      // Atomic compare-and-set: only start while the ride is still `Assigned`. Guards against a
      // concurrent cancel/reassign racing this start — the loser gets InvalidStatusTransition
      // instead of silently overwriting the winner.
      applied      <- rideRepository.updateIfStatus(updatedRide, Set(RideStatus.Assigned)).mapDatabaseError
      _            <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.InProgress)).when(!applied).unit
      persistedRide = updatedRide
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
          .updateIfStatus(updatedRide, Set(RideStatus.Requested, RideStatus.Assigned, RideStatus.InProgress))
          .mapDatabaseError
      _            <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Cancelled)).when(!applied).unit
      persistedRide = updatedRide
    } yield persistedRide

  def cancelRideWithReason(
      rideId: RideId,
      userId: PersonId,
      userRole: PersonRole,
      request: CancelRideRequest
  ): IO[RideError, Ride] =
    for {
      ride         <- getRideById(rideId)
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
      applied      <-
        rideRepository
          .updateIfStatus(updatedRide, Set(RideStatus.Requested, RideStatus.Assigned, RideStatus.InProgress))
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

      // Validate transition
      _               <-
        request.status match
          case RideStatus.InProgress =>
            ZIO
              .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.InProgress))
              .when(!ride.canBeStarted)
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
          case target                => ZIO.fail(RideError.InvalidStatusTransition(ride.status, target))

      // Statuses the ride must still be in for this transition to apply. Mirrors the per-target
      // guards above so the atomic CAS rejects exactly the transitions the in-memory checks would.
      // The `case _` arm is unreachable: any other target already failed via `case target =>`
      // above. It maps to the *full* status set (never an empty set) so that, even if a future
      // refactor lets it through, the CAS still guards on a status rather than silently degrading
      // to "always apply" (an empty set becomes `WHERE ... AND TRUE` in updateIfStatus).
      expectedStatuses =
        request.status match
          case RideStatus.InProgress => Set(RideStatus.Assigned)
          case RideStatus.Completed  => Set(RideStatus.InProgress)
          case RideStatus.Cancelled  => Set(RideStatus.Requested, RideStatus.Assigned, RideStatus.InProgress)
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
      ride <- getRideById(rideId)
      _    <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, ride.status)).when(!ride.canBeEdited).unit
      _    <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(ride.creatorId != userId && userRole != PersonRole.Dispatcher)
          .unit
      // Company isolation: the ride must belong to the caller's company. A missing
      // companyId is treated as a failure (not a bypass) so a caller can never skip the
      // check by omitting it — the HTTP layer always supplies it via requireCompanyId.
      _    <-
        companyId match
          case Some(cid) => ZIO.fail(RideError.UnauthorizedAccess(userId, rideId)).when(ride.companyId != cid).unit
          case None      => ZIO.fail(RideError.UnauthorizedAccess(userId, rideId))

      newPickup  <-
        ZIO.foreach(request.pickupLocation)(loc =>
          geocodingService.enrichLocation(loc).orElse(ZIO.succeed[Location](loc))
        )
      newDropoff <-
        ZIO.foreach(request.dropoffLocation)(loc =>
          geocodingService.enrichLocation(loc).orElse(ZIO.succeed[Location](loc))
        )
      updatedRide = ride
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
                      .replace(request.specifics.orElse(ride.specifics))
                      .focus(_.specialRequirements)
                      .replace(request.specialRequirements.orElse(ride.specialRequirements))

      persistedRide    <- rideRepository.update(updatedRide).mapDatabaseError
      pickupTimeChanged = request.pickupDateTime.exists(_ != ride.pickupDateTime)
      _                <- ZIO.when(pickupTimeChanged)(rideRepository.clearReminders(rideId).mapDatabaseError)
    } yield persistedRide

  def assignDriver(
      rideId: RideId,
      driverId: PersonId,
      overrideScheduleConflict: Boolean = false
  ): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Assigned)).when(!ride.canBeAssigned).unit

      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(driverId))

      _       <- failRule("driver_role", "Person is not a driver").when(!driver.canDrive).unit
      _       <-
        failRule("company_isolation", "Driver belongs to a different company")
          .when(!driver.companyId.contains(ride.companyId))
          .unit

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
      _            <-
        ZIO
          .fail(RideError.InvalidStatusTransition(RideStatus.Assigned, RideStatus.Assigned))
          .when(!applied)
          .unit
      persistedRide = updatedRide
      _            <-
        eventHub
          .publish(
            WebSocketEvent.RideAssigned(
              rideId = persistedRide.id.value,
              driverId = driverId.value,
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _            <-
        emailSmsService
          .sendDriverAssignment(
            RideConfirmationData(
              rideId = persistedRide.id.value.toString,
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
      overrideScheduleConflict: Boolean = false
  ): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <-
        ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Assigned)).when(!ride.canBeReassigned).unit

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

      updatedRide   = ride
                        .focus(_.driverId)
                        .replace(Some(newDriverId))

      // Atomic compare-and-set: only reassign while the ride is still `Assigned`.
      applied      <- rideRepository.updateIfStatus(updatedRide, Set(RideStatus.Assigned)).mapDatabaseError
      _            <-
        ZIO
          .fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Assigned))
          .when(!applied)
          .unit
      persistedRide = updatedRide
      _            <-
        eventHub
          .publish(
            WebSocketEvent.RideAssigned(
              rideId = persistedRide.id.value,
              driverId = newDriverId.value,
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
      // Idempotent: paying an already-paid ride must not overwrite paidAt.
      alreadyPaid    = ride.paymentStatus == PaymentStatus.Paid && paymentStatus == PaymentStatus.Paid
      updatedRide    = ride
                         .focus(_.paymentStatus)
                         .replace(paymentStatus)
                         .focus(_.paymentMethod)
                         .replace(paymentMethod.orElse(ride.paymentMethod))
                         .focus(_.paidAt)
                         .replace(
                           if paymentStatus == PaymentStatus.Paid then
                             if alreadyPaid then ride.paidAt else Some(Instant.now())
                           else ride.paidAt
                         )
      // Marking a ride `Paid` is the only payment transition gated on status (it requires the ride
      // to be Completed). For that case use an atomic compare-and-set so a concurrent cancel racing
      // the payment cannot let a non-Completed ride flip to Paid. Other payment statuses
      // (Pending/Unpaid/...) are legal in any ride status, so they take the plain update.
      // NOTE: the CAS guards the ride status only — two concurrent markPayment(Paid) calls on the
      // same Completed ride can still lost-update each other's payment fields. A field-level CAS
      // (version column) would be needed to close that, and is out of scope here.
      persistedRide <-
        if paymentStatus == PaymentStatus.Paid then
          for {
            applied <- rideRepository.updateIfStatus(updatedRide, Set(RideStatus.Completed)).mapDatabaseError
            _       <-
              ZIO
                .fail(RideError.BusinessRuleViolation("payment_status", "Only a completed ride can be marked paid"))
                .when(!applied)
                .unit
          } yield updatedRide
        else rideRepository.update(updatedRide).mapDatabaseError
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

  private def validateCancelPermission(ride: Ride, userId: PersonId, userRole: PersonRole): IO[RideError, Unit] =
    userRole match
      case PersonRole.Dispatcher | PersonRole.Secretary | PersonRole.Admin | PersonRole.ClientSecretary |
          PersonRole.SuperAdmin =>
        ZIO.unit
      case PersonRole.Client =>
        ZIO.fail(RideError.UnauthorizedAccess(userId, ride.id)).when(ride.clientId != userId).unit
      case PersonRole.Driver =>
        ZIO.fail(RideError.UnauthorizedAccess(userId, ride.id)).when(!ride.driverId.contains(userId)).unit

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
    val candidateTime = candidateRide.scheduledTime.getOrElse(candidateRide.requestTime)
    val windowSeconds = (DefaultRideDurationMinutes + MinBufferMinutes) * 60
    val windowFrom    = candidateTime.minusSeconds(MinBufferMinutes * 60)
    val windowTo      = candidateTime.plusSeconds(windowSeconds)
    for {
      driverRides      <- rideRepository.findByDriverId(driverId).mapDatabaseError
      activeRides       = driverRides.filter(r =>
                            (r.status == RideStatus.Assigned || r.status == RideStatus.InProgress) &&
                              r.id != candidateRide.id // exclude self (relevant for reassign)
                          )
      rideConflict      = activeRides.find { existing =>
                            val existingTime = existing.scheduledTime.getOrElse(existing.requestTime)
                            ridesOverlap(candidateTime, existingTime)
                          }
      _                <-
        rideConflict match
          case Some(conflicting) =>
            val conflictTime = conflicting.scheduledTime.getOrElse(conflicting.requestTime)
            val msg          =
              s"Driver already has ride ${conflicting.id.value} " +
                s"at ${conflictTime} — time windows overlap (buffer ${MinBufferMinutes} min)"
            ZIO.logWarning(s"assignDriver rejected: rule=schedule_conflict msg=$msg") *>
              ZIO.fail(RideError.ScheduleConflict(msg))
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

object RideService:

  val layer: ZLayer[
    RideRepository & PersonRepository & EventHub & EmailSmsService & AuditService & BlacklistRepository & GeocodingService & ExpenseRepository & DriverAvailabilityChecker,
    Nothing,
    RideService
  ] = ZLayer.fromFunction(
    RideServiceImpl.apply
  )
