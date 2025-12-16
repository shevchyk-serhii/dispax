package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{RideId, PersonId, CompanyId}
import com.shevchyk.ride.domain.{Ride, RideStatus}
import zio.*
import java.time.Instant

class InMemoryRideRepository extends RideRepository:
  private val rides = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[RideId, Ride])).getOrThrowFiberFailure()
  }
  override def create(ride: Ride): Task[Ride] =
    val rideWithId = ride.copy(id = RideId.generate())
    rides.update(_.updated(rideWithId.id, rideWithId)).as(rideWithId)

  override def findById(id: RideId): Task[Option[Ride]] =
    rides.get.map(_.get(id))

  override def update(ride: Ride): Task[Ride] =
    rides.update(_.updated(ride.id, ride)).as(ride)

  override def findByClientId(clientId: PersonId): Task[List[Ride]] =
    rides.get.map(_.values.filter(_.clientId == clientId).toList)

  override def findByDriverId(driverId: PersonId): Task[List[Ride]] =
    rides.get.map(_.values.filter(_.driverId.contains(driverId)).toList)

  override def findByStatus(status: RideStatus): Task[List[Ride]] =
    rides.get.map(_.values.filter(_.status == status).toList)

  override def findAll(): Task[List[Ride]] =
    rides.get.map(_.values.toList)

  override def delete(id: RideId): Task[Unit] =
    rides.update(_.removed(id)).unit

object InMemoryRideRepository:
  val layer: ZLayer[Any, Nothing, RideRepository] =
    ZLayer.succeed(new InMemoryRideRepository)