package com.shevchyk.ride.repository

import com.shevchyk.ride.domain.{Ride, RideStatus}
import com.shevchyk.core.domain.{Location, RideId, PersonId, CompanyId}
import zio.*
import java.time.Instant

trait RideRepository {
  def create(ride: Ride): Task[Ride]
  def findById(id: RideId): Task[Option[Ride]]
  def findByStatus(status: RideStatus): Task[List[Ride]]
  def findAll(): Task[List[Ride]]
  def update(ride: Ride): Task[Ride]
  def delete(id: RideId): Task[Unit]
}

final case class MockRideRepository() extends RideRepository {

  override def create(ride: Ride): Task[Ride] = ZIO.succeed(ride)

  override def findById(id: RideId): Task[Option[Ride]] = {
    ZIO.succeed(
      Some(
        Ride(
          id = id,
          clientId = PersonId(1),
          creatorId = PersonId(1),
          companyId = CompanyId(1),
          status = RideStatus.Requested,
          pickupLocation = Location("Mock Pickup Location"),
          dropoffLocation = Location("Mock Destination Location")
        )
      )
    )
  }

  override def findByStatus(status: RideStatus): Task[List[Ride]] = {
    ZIO.succeed(
      List(
        Ride(
          id = RideId(1),
          clientId = PersonId(1),
          creatorId = PersonId(1),
          companyId = CompanyId(1),
          status = status,
          pickupLocation = Location("Mock Pickup Location"),
          dropoffLocation = Location("Mock Destination Location")
        )
      )
    )
  }

  override def findAll(): Task[List[Ride]] = {
    ZIO.succeed(
      List(
        Ride(
          id = RideId(1),
          clientId = PersonId(1),
          creatorId = PersonId(1),
          companyId = CompanyId(1),
          status = RideStatus.Requested,
          pickupLocation = Location("Mock Pickup Location"),
          dropoffLocation = Location("Mock Destination Location")
        )
      )
    )
  }

  override def update(ride: Ride): Task[Ride] = ZIO.succeed(ride)

  override def delete(id: RideId): Task[Unit] = ZIO.succeed(())
}

object RideRepository {
  val layer: ZLayer[Any, Nothing, RideRepository] = ZLayer.succeed(MockRideRepository())
}
