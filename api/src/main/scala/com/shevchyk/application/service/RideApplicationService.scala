package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.service.RideDomainService
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*
import java.time.LocalDateTime

case class RideApplicationService(
    rideRepo: RideRepository,
    driverRepo: DriverRepository,
    personRepo: PersonRepository,
    tariffRepo: TariffRepository,
    notificationService: NotificationService,
    locationService: LocationService,
    flightInfoService: FlightInfoService
):

  def createRide(request: CreateRideRequest): IO[RideError, Ride] =
    for

      _ <- ZIO
             .fromEither(
               RideDomainService.validateRideRequest(
                 request.clientId,
                 request.from,
                 request.to,
                 request.pickupDateTime
               )
             )
             .mapError(RideError.ValidationError.apply)

      client <- personRepo
                  .findById(request.clientId)
                  .mapError(ErrorMapper.fromRepositoryError)
                  .someOrFail(RideError.PersonNotFound(request.clientId))

      routeInfo <- locationService
                     .calculateRoute(request.from, request.to)
                     .mapError(ErrorMapper.fromLocationError)

      tariff <- tariffRepo
                  .findByCompanyId(client.companyId.getOrElse(CompanyId(1)))
                  .mapError(ErrorMapper.fromRepositoryError)
                  .someOrFail(RideError.TariffNotFound(client.companyId.getOrElse(CompanyId(1))))

      price = RideDomainService.calculatePrice(
                routeInfo.distance,
                tariff,
                request.pickupDateTime,
                request.from.address.toLowerCase.contains("airport") || request.to.address.toLowerCase
                  .contains("airport")
              )

      ride = Ride(
               id = RideId.generate(),
               clientId = request.clientId,
               creatorId = request.creatorId,
               companyId = client.companyId.getOrElse(CompanyId(1)),
               pickupDateTime = request.pickupDateTime,
               from = request.from,
               to = request.to,
               status = RideStatus.Requested,
               flightInfo = request.flightNumber.map(fn =>
                 FlightInfo(
                   fn,
                   request.pickupDateTime,
                   isArrival = request.from.address.toLowerCase.contains("airport")
                 )
               ),
               price = Some(price),
               estimatedDistance = Some(routeInfo.distance)
             )

      savedRide <- rideRepo.save(ride).mapError(ErrorMapper.fromRepositoryError)

      _ <-
        notificationService
          .notifyClient(
            request.clientId,
            s"Your ride has been created. Estimated price: ${price.amount} ${price.currency}",
            Some(savedRide.id)
          )
          .mapError(ErrorMapper.fromNotificationError("NotificationService"))
          .ignore

      _ <-
        notificationService
          .notifyCompany(
            client.companyId.getOrElse(CompanyId(1)),
            s"New ride request from ${client.name}",
            Some(savedRide.id)
          )
          .mapError(ErrorMapper.fromNotificationError("NotificationService"))
          .ignore
    yield savedRide

  def assignDriverToRide(rideId: RideId, requesterId: PersonId): IO[RideError, Ride] =
    for

      ride <- rideRepo
                .findById(rideId)
                .mapError(ErrorMapper.fromRepositoryError)
                .someOrFail(RideError.RideNotFound(rideId))

      _ <-
        ZIO.when(ride.driverId.isDefined)(
          ZIO.fail(RideError.RideAlreadyAssigned(rideId, ride.driverId.get))
        )

      maxSearchRadius   = Distance(20.0)
      availableDrivers <- driverRepo
                            .findAvailableNear(ride.from, maxSearchRadius)
                            .mapError(ErrorMapper.fromRepositoryError)

      suitableDrivers = availableDrivers.filter(
                          RideDomainService.isDriverSuitableForRide(_, ride, maxSearchRadius)
                        )

      bestDriver <- ZIO
                      .fromOption(
                        RideDomainService.assignBestDriver(suitableDrivers, ride.from)
                      )
                      .orElseFail(RideError.NoDriversAvailable(ride.from.address))

      assignedRide = ride.assignDriver(bestDriver.id)
      updatedRide <- rideRepo
                       .update(assignedRide)
                       .mapError(ErrorMapper.fromRepositoryError)
                       .someOrFail(RideError.RideNotFound(rideId))

      _ <- driverRepo
             .updateStatus(bestDriver.id, DriverStatus.Busy)
             .mapError(ErrorMapper.fromRepositoryError)

      _ <-
        notificationService
          .notifyDriver(
            bestDriver.id,
            s"New ride assigned: from ${ride.from.address} to ${ride.to.address}",
            Some(rideId)
          )
          .mapError(ErrorMapper.fromNotificationError("NotificationService"))
          .ignore

      _ <-
        notificationService
          .notifyClient(
            ride.clientId,
            s"Driver ${bestDriver.name} has been assigned to your ride",
            Some(rideId)
          )
          .mapError(ErrorMapper.fromNotificationError("NotificationService"))
          .ignore
    yield updatedRide

  def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for
      ride <- getRideById(rideId)

      _ <-
        ZIO.when(!ride.driverId.contains(driverId))(
          ZIO.fail(RideError.UnauthorizedAccess(driverId, rideId))
        )

      startedRide <- ZIO
                       .fromEither(ride.startRide())
                       .mapError(RideError.ValidationError.apply)

      updatedRide <- rideRepo
                       .update(startedRide)
                       .mapError(ErrorMapper.fromRepositoryError)
                       .someOrFail(RideError.RideNotFound(rideId))

      _ <-
        notificationService
          .notifyClient(
            ride.clientId,
            "Your ride has started",
            Some(rideId)
          )
          .mapError(ErrorMapper.fromNotificationError("NotificationService"))
          .ignore
    yield updatedRide

  def completeRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride] =
    for
      ride <- getRideById(rideId)

      _ <-
        ZIO.when(!ride.driverId.contains(driverId))(
          ZIO.fail(RideError.UnauthorizedAccess(driverId, rideId))
        )

      completedRide <- ZIO
                         .fromEither(ride.completeRide())
                         .mapError(RideError.ValidationError.apply)

      updatedRide <- rideRepo
                       .update(completedRide)
                       .mapError(ErrorMapper.fromRepositoryError)
                       .someOrFail(RideError.RideNotFound(rideId))

      _ <- driverRepo
             .updateStatus(driverId, DriverStatus.Available)
             .mapError(ErrorMapper.fromRepositoryError)

      _ <-
        notificationService
          .notifyClient(
            ride.clientId,
            s"Your ride is completed. Total: ${ride.price.map(p => s"${p.amount} ${p.currency}").getOrElse("N/A")}",
            Some(rideId)
          )
          .mapError(ErrorMapper.fromNotificationError("NotificationService"))
          .ignore
    yield updatedRide

  def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride] =
    for
      ride <- getRideById(rideId)

      _ <-
        ZIO.when(!RideDomainService.canCancelRide(ride, userRole, userId))(
          ZIO.fail(RideError.UnauthorizedAccess(userId, rideId))
        )

      cancelledRide <- ZIO
                         .fromEither(ride.cancel())
                         .mapError(RideError.ValidationError.apply)

      updatedRide <- rideRepo
                       .update(cancelledRide)
                       .mapError(ErrorMapper.fromRepositoryError)
                       .someOrFail(RideError.RideNotFound(rideId))

      _ <-
        ride.driverId match
          case Some(driverId) =>
            driverRepo
              .updateStatus(driverId, DriverStatus.Available)
              .mapError(ErrorMapper.fromRepositoryError)
          case None           => ZIO.unit

      _ <-
        notificationService
          .notifyClient(
            ride.clientId,
            "Your ride has been cancelled",
            Some(rideId)
          )
          .mapError(ErrorMapper.fromNotificationError("NotificationService"))
          .ignore

      _ <-
        ride.driverId.fold(ZIO.unit)(driverId =>
          notificationService
            .notifyDriver(
              driverId,
              s"Ride has been cancelled: ${ride.from.address} to ${ride.to.address}",
              Some(rideId)
            )
            .mapError(ErrorMapper.fromNotificationError("NotificationService"))
            .ignore
        )
    yield updatedRide

  def getRideById(rideId: RideId): IO[RideError, Ride] = rideRepo
    .findById(rideId)
    .mapError(ErrorMapper.fromRepositoryError)
    .someOrFail(RideError.RideNotFound(rideId))

  def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]] =
    for
      user <- personRepo
                .findById(userId)
                .mapError(ErrorMapper.fromRepositoryError)
                .someOrFail(RideError.PersonNotFound(userId))

      allRides <-
        user.role match
          case PersonRole.driver                            => rideRepo.findByDriverId(userId).mapError(ErrorMapper.fromRepositoryError)
          case PersonRole.client                            => rideRepo.findByClientId(userId).mapError(ErrorMapper.fromRepositoryError)
          case PersonRole.secretary | PersonRole.dispatcher =>
            user.companyId match
              case Some(companyId) => rideRepo.findByCompanyId(companyId).mapError(ErrorMapper.fromRepositoryError)
              case None            => ZIO.succeed(List.empty)
          case _                                            => ZIO.succeed(List.empty)

      filteredRides = RideDomainService.filterRidesForUser(allRides, user)
    yield filteredRides

  def enrichRideWithFlightInfo(ride: Ride): IO[RideError, Ride] =
    ride.flightInfo match
      case Some(flightInfo) =>
        flightInfoService
          .getFlightInfo(flightInfo.flightNumber, ride.pickupDateTime.toLocalDate)
          .mapError(ErrorMapper.fromFlightError)
          .map {
            case Some(updatedFlightInfo) => ride.copy(flightInfo = Some(updatedFlightInfo))
            case None                    => ride
          }
      case None             => ZIO.succeed(ride)

case class CreateRideRequest(
    clientId: PersonId,
    creatorId: PersonId,
    from: Location,
    to: Location,
    pickupDateTime: LocalDateTime,
    flightNumber: Option[String] = None
) derives zio.json.JsonCodec

object RideApplicationService:

  val layer: ZLayer[
    RideRepository & DriverRepository & PersonRepository & TariffRepository & NotificationService & LocationService & FlightInfoService,
    Nothing,
    RideApplicationService
  ] = ZLayer.fromFunction(RideApplicationService.apply)
