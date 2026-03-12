package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{EventHub, AuditService}
import com.shevchyk.core.repository.BlacklistRepository
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.domain.RepositoryExtensions.*
import com.shevchyk.ride.repository.RideRepository
import com.shevchyk.repository.PersonRepository
import com.shevchyk.core.application.{EmailSmsService, RideConfirmationData}
import zio.*
import java.time.Instant
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

  def updateRideDetails(
      rideId: RideId,
      request: UpdateRideDetailsRequest,
      userId: PersonId,
      userRole: PersonRole
  ): IO[RideError, Ride]
  def reassignDriver(rideId: RideId, newDriverId: PersonId): IO[RideError, Ride]
  def markPayment(rideId: RideId, paymentStatus: String, paymentMethod: Option[String]): IO[RideError, Ride]
  def getUnpaidCompletedRides: IO[RideError, List[Ride]]

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
          .ignore
    } yield persistedRide

  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]] = rideRepository
    .findByClientId(userId)
    .orElse(rideRepository.findByDriverId(userId))
    .mapError(ex => RideError.DatabaseError(ex))

  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <- ZIO.fail(RideError.DriverNotFound(driverId)).when(!ride.canBeStarted).unit

      driverOpt <- personRepository.findById(driverId).mapDatabaseError
      _         <- ZIO.fromOption(driverOpt).orElseFail(RideError.DriverNotFound(driverId))

      updatedRide = ride
                      .focus(_.status)
                      .replace(RideStatus.InProgress)
                      .focus(_.driverId)
                      .replace(Some(driverId))
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
      _    <- ZIO.fail(RideError.UnauthorizedAccess(userId, rideId)).when(ride.status == RideStatus.Completed).unit

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
      _    <- ZIO.fail(RideError.UnauthorizedAccess(userId, rideId)).when(ride.status == RideStatus.Completed).unit

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
          .ignore
    } yield persistedRide

  def updateRideDetails(
      rideId: RideId,
      request: UpdateRideDetailsRequest,
      userId: PersonId,
      userRole: PersonRole
  ): IO[RideError, Ride] =
    for {
      ride <- getRideById(rideId)
      _    <- ZIO.fail(RideError.InvalidStatusTransition(ride.status, ride.status)).when(!ride.canBeEdited).unit
      _    <-
        ZIO
          .fail(RideError.UnauthorizedAccess(userId, rideId))
          .when(ride.creatorId != userId && userRole != PersonRole.Dispatcher)
          .unit

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

      _                <-
        ZIO
          .fail(RideError.BusinessRuleViolation("driver_role", "Person is not a driver"))
          .when(driver.role != PersonRole.Driver)
          .unit
      _                <-
        ZIO
          .fail(RideError.BusinessRuleViolation("company_isolation", "Driver belongs to a different company"))
          .when(!driver.companyId.contains(ride.companyId))
          .unit

      // Check blacklist
      blocked          <- blacklistRepository.isBlacklisted(ride.clientId, driverId).mapDatabaseError
      _                <-
        ZIO
          .fail(RideError.BusinessRuleViolation("blacklist", "This driver is blacklisted for the ride's client"))
          .when(blocked)
          .unit

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

  def markPayment(rideId: RideId, paymentStatus: String, paymentMethod: Option[String]): IO[RideError, Ride] =
    for {
      ride          <- getRideById(rideId)
      updatedRide    = ride
                         .focus(_.paymentStatus)
                         .replace(Some(paymentStatus))
                         .focus(_.paymentMethod)
                         .replace(paymentMethod.orElse(ride.paymentMethod))
                         .focus(_.paidAt)
                         .replace(if paymentStatus == "paid" then Some(Instant.now()) else ride.paidAt)
      persistedRide <- rideRepository.update(updatedRide).mapDatabaseError
    } yield persistedRide

  def getUnpaidCompletedRides: IO[RideError, List[Ride]] = rideRepository
    .findByStatus(RideStatus.Completed)
    .mapDatabaseError
    .map(_.filter(r => r.paymentStatus.isEmpty || r.paymentStatus.contains("unpaid")))

object RideService:

  val layer
      : ZLayer[RideRepository & PersonRepository & EventHub & EmailSmsService & AuditService & BlacklistRepository, Nothing, RideService] =
    ZLayer.fromFunction(
      RideServiceImpl.apply
    )
