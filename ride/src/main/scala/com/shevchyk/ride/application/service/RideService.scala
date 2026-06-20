package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{EventHub, AuditService, GeocodingService}
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
  def assignDriver(rideId: RideId, driverId: PersonId): IO[RideError, Ride]
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

class RideServiceImpl(
    rideRepository: RideRepository,
    personRepository: PersonRepository,
    eventHub: EventHub,
    emailSmsService: EmailSmsService,
    auditService: AuditService,
    blacklistRepository: BlacklistRepository,
    geocodingService: GeocodingService,
    expenseRepository: ExpenseRepository
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

      updatedRide = ride
                      .focus(_.status)
                      .replace(RideStatus.InProgress)
                      .focus(_.startTime)
                      .replace(Some(Instant.now()))

      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
    } yield persistedRide

  def completeRide(rideId: RideId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <-
        ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Completed)).when(!ride.canBeCompleted).unit

      updatedRide = ride
                      .focus(_.status)
                      .replace(RideStatus.Completed)
                      .focus(_.endTime)
                      .replace(Some(Instant.now()))

      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
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

      updatedRide    = ride.focus(_.status).replace(RideStatus.Cancelled)
      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
    } yield persistedRide

  def cancelRideWithReason(
      rideId: RideId,
      userId: PersonId,
      userRole: PersonRole,
      request: CancelRideRequest
  ): IO[RideError, Ride] =
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
      // A cancellation fee charges the client; a negative value would credit them instead.
      // Guard here too (not only at the HTTP validator) so direct callers can't bypass it.
      _    <-
        ZIO
          .fail(RideError.ValidationError("Cancellation fee cannot be negative"))
          .when(request.fee.exists(_ < 0))
          .unit

      updatedRide    = ride
                         .focus(_.status)
                         .replace(RideStatus.Cancelled)
                         .focus(_.cancellationReason)
                         .replace(Some(request.reason))
                         .focus(_.cancellationFee)
                         .replace(request.fee)
                         .focus(_.cancelledBy)
                         .replace(Some(userId))
      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
      _             <-
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
      _             <-
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
      _ <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(userRole == PersonRole.Driver && !ride.driverId.contains(userId))
          .unit
      _ <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(userRole != PersonRole.Driver && userRole != PersonRole.Dispatcher)
          .unit

      // Validate transition
      _ <-
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

      updatedRide = ride
                      .focus(_.status)
                      .replace(request.status)
                      .focus(_.notes)
                      .replace(request.notes.orElse(ride.notes))
                      .focus(_.startTime)
                      .replace(if request.status == RideStatus.InProgress then Some(Instant.now()) else ride.startTime)
                      .focus(_.endTime)
                      .replace(if request.status == RideStatus.Completed then Some(Instant.now()) else ride.endTime)

      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
      _             <-
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
      _             <-
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

  def assignDriver(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
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

      // Check scheduling conflicts
      _ <- checkScheduleConflict(driverId, ride)

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
      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
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
   * Checks whether ``driverId`` has any active ride (Assigned / InProgress) whose time window overlaps with
   * ``candidateRide``.
   *
   * A ride's "occupied window" is: [scheduledTime − buffer, scheduledTime + estimatedDuration + buffer]
   *
   * Without real ETA data we assume a default ride duration of 60 min.
   */
  private def checkScheduleConflict(driverId: PersonId, candidateRide: Ride): IO[RideError, Unit] =
    val candidateTime = candidateRide.scheduledTime.getOrElse(candidateRide.requestTime)
    for {
      driverRides <- rideRepository.findByDriverId(driverId).mapDatabaseError
      activeRides  = driverRides.filter(r =>
                       (r.status == RideStatus.Assigned || r.status == RideStatus.InProgress) &&
                         r.id != candidateRide.id // exclude self (relevant for reassign)
                     )
      conflict     = activeRides.find { existing =>
                       val existingTime = existing.scheduledTime.getOrElse(existing.requestTime)
                       ridesOverlap(candidateTime, existingTime)
                     }
      _           <-
        conflict match
          case Some(conflicting) =>
            val conflictTime = conflicting.scheduledTime.getOrElse(conflicting.requestTime)
            val msg          =
              s"Driver already has ride ${conflicting.id.value} " +
                s"at ${conflictTime} — time windows overlap (buffer ${MinBufferMinutes} min)"
            ZIO.logWarning(s"assignDriver rejected: rule=schedule_conflict msg=$msg") *>
              ZIO.fail(RideError.ScheduleConflict(msg))
          case None              => ZIO.unit
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
    val DefaultRideDurationMinutes = 60L
    val windowSeconds              = (DefaultRideDurationMinutes + MinBufferMinutes) * 60
    val existingEnd                = existingTime.plusSeconds(windowSeconds)
    val candidateEnd               = candidateTime.plusSeconds(windowSeconds)
    // Standard interval overlap: [existingStart, existingEnd) overlaps [candidateStart, candidateEnd) iff:
    candidateTime.isBefore(existingEnd) && existingTime.isBefore(candidateEnd)

object RideService:

  val layer
      : ZLayer[RideRepository & PersonRepository & EventHub & EmailSmsService & AuditService & BlacklistRepository & GeocodingService & ExpenseRepository, Nothing, RideService] =
    ZLayer.fromFunction(
      RideServiceImpl.apply
    )
