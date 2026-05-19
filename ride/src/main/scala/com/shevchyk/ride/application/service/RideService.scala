package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{EventHub, AuditService}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.domain.RepositoryExtensions.*
import com.shevchyk.ride.repository.RideRepository
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.core.application.{EmailSmsService, RideConfirmationData}
import zio.*
import java.time.{Duration, Instant}
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
  def getDriverRides(driverId: PersonId): IO[RideError, List[Ride]]
  def getClientRides(clientId: PersonId): IO[RideError, List[Ride]]
  def getAllRides: IO[RideError, List[Ride]]
  def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]
  def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]]
  def getDriverRidesPaginated(driverId: PersonId, offset: Int, limit: Int): IO[RideError, List[Ride]]

  def updateRideDetails(
      rideId: RideId,
      request: UpdateRideDetailsRequest,
      userId: PersonId,
      userRole: PersonRole,
      companyId: Option[CompanyId] = None
  ): IO[RideError, Ride]
  def reassignDriver(rideId: RideId, newDriverId: PersonId): IO[RideError, Ride]

  def markPayment(
      rideId: RideId,
      paymentStatus: PaymentStatus,
      paymentMethod: Option[PaymentMethod]
  ): IO[RideError, Ride]
  def getUnpaidCompletedRides: IO[RideError, List[Ride]]
  def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]
  def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]
  def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]
  def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]
  def getDailyStats(companyId: CompanyId, days: Int): IO[RideError, List[(String, Int, Int, Int)]]

class RideServiceImpl(
    rideRepository: RideRepository,
    personRepository: PersonRepository,
    eventHub: EventHub,
    emailSmsService: EmailSmsService,
    auditService: AuditService,
    blacklistRepository: BlacklistRepository
) extends RideService:

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideRepository
    .findById(rideId)
    .mapDatabaseError
    .flatMap {
      case Some(ride) => ZIO.succeed(ride)
      case None       => ZIO.fail(RideError.RideNotFound(rideId))
    }

  def createRide(request: CreateRideRequest): IO[RideError, Ride] =
    for {
      // Validate pickup is in the future (allow 5 min tolerance for clock skew)
      _             <-
        request.scheduledTime match
          case Some(t) if t.isBefore(Instant.now().minusSeconds(300)) =>
            ZIO.fail(RideError.ValidationError("Pickup time must be in the future"))
          case _                                                      => ZIO.unit
      // Validate addresses differ
      _             <-
        ZIO
          .fail(RideError.ValidationError("Pickup and dropoff addresses must be different"))
          .when(request.pickupLocation.address == request.dropoffLocation.address)
          .unit
      ride          <- ZIO.succeed(RideMapper.fromRequest(request))
      persistedRide <- rideRepository.create(ride).mapDatabaseError
      _             <-
        eventHub
          .publish(
            WebSocketEvent.RideCreated(
              rideId = persistedRide.id.value,
              clientId = persistedRide.clientId.value,
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _             <-
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
      _             <-
        auditService
          .log(
            AuditLogEntry(
              id = AuditLogId.generate(),
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
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _             <-
        auditService
          .log(
            AuditLogEntry(
              id = AuditLogId.generate(),
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
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _             <-
        auditService
          .log(
            AuditLogEntry(
              id = AuditLogId.generate(),
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
      companyId: Option[CompanyId] = None
  ): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, ride.status)).when(!ride.canBeEdited).unit
      _    <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(ride.creatorId != userId && userRole != PersonRole.Dispatcher)
          .unit
      // Company isolation: ensure ride belongs to user's company
      _    <-
        companyId match
          case Some(cid) => ZIO.fail(RideError.UnauthorizedAccess(userId, rideId)).when(ride.companyId != cid).unit
          case None      => ZIO.unit

      updatedRide = ride
                      .focus(_.pickupLocation)
                      .replace(request.pickupLocation.getOrElse(ride.pickupLocation))
                      .focus(_.dropoffLocation)
                      .replace(request.dropoffLocation.getOrElse(ride.dropoffLocation))
                      .focus(_.scheduledTime)
                      .replace(request.scheduledTime.orElse(ride.scheduledTime))
                      .focus(_.notes)
                      .replace(request.notes.orElse(ride.notes))
                      .focus(_.specifics)
                      .replace(request.specifics.orElse(ride.specifics))
                      .focus(_.specialRequirements)
                      .replace(request.specialRequirements.orElse(ride.specialRequirements))

      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
    } yield persistedRide

  def assignDriver(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Assigned)).when(!ride.canBeAssigned).unit

      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(driverId))

      _       <-
        ZIO
          .fail(RideError.BusinessRuleViolation("driver_role", "Person is not a driver"))
          .when(driver.role != PersonRole.Driver)
          .unit
      _       <-
        ZIO
          .fail(RideError.BusinessRuleViolation("company_isolation", "Driver belongs to a different company"))
          .when(!driver.companyId.contains(ride.companyId))
          .unit

      // Check blacklist
      blocked <- blacklistRepository.isBlacklisted(ride.clientId, driverId).mapDatabaseError
      _       <-
        ZIO
          .fail(RideError.BusinessRuleViolation("blacklist", "This driver is blacklisted for the ride's client"))
          .when(blocked)
          .unit

      // Check scheduling conflicts
      _       <- checkScheduleConflict(driverId, ride)

      // Check VIP and preferred driver
      clientOpt        <- personRepository.findById(ride.clientId).mapDatabaseError
      isVip             = clientOpt.exists(_.isVip)
      isPreferredDriver = clientOpt.flatMap(_.preferredDriverId).contains(driverId)

      updatedRide = ride
                      .focus(_.status)
                      .replace(RideStatus.Assigned)
                      .focus(_.driverId)
                      .replace(Some(driverId))
                      .focus(_.isVipRide)
                      .replace(isVip)
                      .focus(_.preferredDriverUsed)
                      .replace(isPreferredDriver)

      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
      _             <-
        eventHub
          .publish(
            WebSocketEvent.RideAssigned(
              rideId = persistedRide.id.value,
              driverId = driverId.value,
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _             <-
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
      _             <-
        auditService
          .log(
            AuditLogEntry(
              id = AuditLogId.generate(),
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

  def reassignDriver(rideId: RideId, newDriverId: PersonId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <-
        ZIO.fail(RideError.InvalidStatusTransition(ride.status, RideStatus.Assigned)).when(!ride.canBeReassigned).unit

      driverOpt <- personRepository.findById(newDriverId).mapDatabaseError
      driver    <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(newDriverId))

      _       <-
        ZIO
          .fail(RideError.BusinessRuleViolation("driver_role", "Person is not a driver"))
          .when(driver.role != PersonRole.Driver)
          .unit
      _       <-
        ZIO
          .fail(RideError.BusinessRuleViolation("company_isolation", "Driver belongs to a different company"))
          .when(!driver.companyId.contains(ride.companyId))
          .unit

      // Check blacklist
      blocked <- blacklistRepository.isBlacklisted(ride.clientId, newDriverId).mapDatabaseError
      _       <-
        ZIO
          .fail(RideError.BusinessRuleViolation("blacklist", "This driver is blacklisted for the ride's client"))
          .when(blocked)
          .unit

      // Check scheduling conflicts (exclude current ride from conflict check)
      _       <- checkScheduleConflict(newDriverId, ride)

      updatedRide = ride
                      .focus(_.driverId)
                      .replace(Some(newDriverId))

      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
      _             <-
        eventHub
          .publish(
            WebSocketEvent.RideAssigned(
              rideId = persistedRide.id.value,
              driverId = newDriverId.value,
              companyId = persistedRide.companyId.value
            )
          )
          .ignore
      _             <-
        auditService
          .log(
            AuditLogEntry(
              id = AuditLogId.generate(),
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

  def getDriverRides(driverId: PersonId): IO[RideError, List[Ride]] =
    rideRepository.findByDriverId(driverId).mapDatabaseError

  def getClientRides(clientId: PersonId): IO[RideError, List[Ride]] =
    rideRepository.findByClientId(clientId).mapDatabaseError

  def getAllRides: IO[RideError, List[Ride]] = rideRepository.findAll().mapDatabaseError

  def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]] =
    rideRepository.findByCompanyId(companyId).mapDatabaseError

  def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]] =
    rideRepository
      .findByCompanyId(companyId)
      .mapDatabaseError
      .map(_.sortBy(_.requestTime).reverse.drop(offset).take(limit))

  def getDriverRidesPaginated(driverId: PersonId, offset: Int, limit: Int): IO[RideError, List[Ride]] = rideRepository
    .findByDriverId(driverId)
    .mapDatabaseError
    .map(_.sortBy(_.requestTime).reverse.drop(offset).take(limit))

  def markPayment(
      rideId: RideId,
      paymentStatus: PaymentStatus,
      paymentMethod: Option[PaymentMethod]
  ): IO[RideError, Ride] =
    for {
      ride          <- getRideById(rideId)
      updatedRide    = ride
                         .focus(_.paymentStatus)
                         .replace(paymentStatus)
                         .focus(_.paymentMethod)
                         .replace(paymentMethod.orElse(ride.paymentMethod))
                         .focus(_.paidAt)
                         .replace(if paymentStatus == PaymentStatus.Paid then Some(Instant.now()) else ride.paidAt)
      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
    } yield persistedRide

  def getUnpaidCompletedRides: IO[RideError, List[Ride]] = rideRepository
    .findByStatus(RideStatus.Completed)
    .mapDatabaseError
    .map(_.filter(r => r.paymentStatus == PaymentStatus.Unpaid))

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

  // -- Cancel permission --------------------------------------------------

  private def validateCancelPermission(ride: Ride, userId: PersonId, userRole: PersonRole): IO[RideError, Unit] =
    userRole match
      case PersonRole.Dispatcher | PersonRole.Secretary | PersonRole.Admin => ZIO.unit
      case PersonRole.Client                                               =>
        ZIO.fail(RideError.UnauthorizedAccess(userId, ride.id)).when(ride.clientId != userId).unit
      case PersonRole.Driver                                               =>
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
            ZIO.fail(
              RideError.BusinessRuleViolation(
                "schedule_conflict",
                s"Driver already has ride ${conflicting.id.value} " +
                  s"at ${conflictTime} — insufficient buffer (min ${MinBufferMinutes} min)"
              )
            )
          case None              => ZIO.unit
    } yield ()

  /**
   * Two rides overlap when the gap between their scheduled times is less than the buffer.
   */
  private def ridesOverlap(t1: Instant, t2: Instant): Boolean =
    val DefaultRideDurationMinutes = 60L
    val gap                        = Math.abs(Duration.between(t1, t2).toMinutes)
    gap < (DefaultRideDurationMinutes + MinBufferMinutes)

object RideService:

  val layer
      : ZLayer[RideRepository & PersonRepository & EventHub & EmailSmsService & AuditService & BlacklistRepository, Nothing, RideService] =
    ZLayer.fromFunction(
      RideServiceImpl.apply
    )
