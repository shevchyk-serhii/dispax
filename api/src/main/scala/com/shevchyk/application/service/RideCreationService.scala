package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.service.RideDomainService
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*
import java.time.LocalDateTime

case class RideCreationService(
    rideRepo: RideRepository,
    personRepo: PersonRepository,
    tariffRepo: TariffRepository
):

  def createRide(request: CreateRideRequest): IO[RideError, CreatedRide] =
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

      tariff <- tariffRepo
                  .findByCompanyId(client.companyId.getOrElse(CompanyId(1)))
                  .mapError(ErrorMapper.fromRepositoryError)
                  .someOrFail(RideError.TariffNotFound(client.companyId.getOrElse(CompanyId(1))))

      ride = createRideEntity(request, client, tariff)

      savedRide <- rideRepo.save(ride).mapError(ErrorMapper.fromRepositoryError)
    yield CreatedRide(savedRide, client)

  private def createRideEntity(
      request: CreateRideRequest,
      client: Person,
      tariff: Tariff
  ): Ride =

    val isAirportTransfer = isAirportRoute(request.from, request.to)
    val estimatedDistance = Distance(10.0)
    val price             = RideDomainService.calculatePrice(
      estimatedDistance,
      tariff,
      request.pickupDateTime,
      isAirportTransfer
    )

    Ride(
      id = RideId.generate(),
      clientId = request.clientId,
      creatorId = request.creatorId,
      companyId = client.companyId.getOrElse(CompanyId(1)),
      pickupDateTime = request.pickupDateTime,
      from = request.from,
      to = request.to,
      status = RideStatus.Requested,
      flightInfo = request.flightNumber.map(fn =>
        FlightInfo(fn, request.pickupDateTime, isArrival = request.from.address.toLowerCase.contains("airport"))
      ),
      price = Some(price),
      estimatedDistance = Some(estimatedDistance)
    )

  private def isAirportRoute(from: Location, to: Location): Boolean =
    from.address.toLowerCase.contains("airport") || to.address.toLowerCase.contains("airport")
case class CreatedRide(ride: Ride, client: Person)

object RideCreationService:

  val layer: ZLayer[RideRepository & PersonRepository & TariffRepository, Nothing, RideCreationService] = ZLayer
    .fromFunction(RideCreationService.apply)
