package com.shevchyk.infrastructure.repository

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.{RideRepository, RepositoryError}
import zio.*
import java.time.LocalDateTime
import scala.collection.mutable

case class InMemoryRideRepository(storage: Ref[Map[RideId, Ride]]) extends RideRepository:

  override def save(ride: Ride): IO[RepositoryError, Ride] = storage.update(_ + (ride.id -> ride)).as(ride)

  override def findById(id: RideId): IO[RepositoryError, Option[Ride]] = storage.get.map(_.get(id))

  override def findAll(): IO[RepositoryError, List[Ride]] = storage.get.map(_.values.toList)

  override def findByClientId(clientId: PersonId): IO[RepositoryError, List[Ride]] = storage.get.map(
    _.values.filter(_.clientId == clientId).toList
  )

  override def findByDriverId(driverId: PersonId): IO[RepositoryError, List[Ride]] = storage.get.map(
    _.values.filter(_.driverId.contains(driverId)).toList
  )

  override def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Ride]] = storage.get.map(
    _.values.filter(_.companyId == companyId).toList
  )

  override def findByStatus(status: RideStatus): IO[RepositoryError, List[Ride]] = storage.get.map(
    _.values.filter(_.status == status).toList
  )

  override def update(ride: Ride): IO[RepositoryError, Option[Ride]] =
    for
      exists <- storage.get.map(_.contains(ride.id))
      result <-
        if exists then storage.update(_ + (ride.id -> ride)).as(Some(ride))
        else ZIO.succeed(None)
    yield result

  override def delete(id: RideId): IO[RepositoryError, Boolean] =
    for
      exists <- storage.get.map(_.contains(id))
      _      <- if exists then storage.update(_ - id) else ZIO.unit
    yield exists

object InMemoryRideRepository:

  val layer: ZLayer[Any, Nothing, RideRepository] = ZLayer.fromZIO(
    Ref.make(mockRides).map(InMemoryRideRepository(_))
  )

  private val mockRides: Map[RideId, Ride] = Map(
    RideId(1) -> Ride(
      id = RideId(1),
      clientId = PersonId(2),
      creatorId = PersonId(3),
      driverId = Some(PersonId(1)),
      companyId = CompanyId(1),
      pickupDateTime = LocalDateTime.now().plusHours(2),
      from = Location("Downtown Munich"),
      to = Location("Munich Airport (MUC)"),
      status = RideStatus.Assigned,
      flightInfo = Some(
        FlightInfo(
          flightNumber = "LH123",
          flightTime = LocalDateTime.now().plusHours(3),
          gate = Some("A12"),
          terminal = Some("2"),
          status = "On Time",
          isArrival = false
        )
      ),
      price = Some(Price(45.50, "EUR")),
      estimatedDistance = Some(Distance(35.0))
    ),
    RideId(2) -> Ride(
      id = RideId(2),
      clientId = PersonId(2),
      creatorId = PersonId(3),
      companyId = CompanyId(1),
      pickupDateTime = LocalDateTime.now().plusHours(5),
      from = Location("Railway Station"),
      to = Location("Kiev National University"),
      status = RideStatus.Requested,
      price = Some(Price(25.00, "EUR")),
      estimatedDistance = Some(Distance(15.0))
    ),
    RideId(3) -> Ride(
      id = RideId(3),
      clientId = PersonId(2),
      creatorId = PersonId(4),
      driverId = Some(PersonId(1)),
      companyId = CompanyId(1),
      pickupDateTime = LocalDateTime.now().plusDays(1),
      from = Location("Independence Square"),
      to = Location("Golden Gate"),
      status = RideStatus.InProgress,
      price = Some(Price(18.75, "EUR")),
      estimatedDistance = Some(Distance(8.5))
    )
  )
