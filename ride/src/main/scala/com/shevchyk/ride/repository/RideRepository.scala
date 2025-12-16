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
  def findByClientId(clientId: PersonId): Task[List[Ride]]
  def findByDriverId(driverId: PersonId): Task[List[Ride]]
  def update(ride: Ride): Task[Ride]
  def delete(id: RideId): Task[Unit]
}

object RideRepository {
  import com.shevchyk.database.DatabaseConfig
  import doobie.Transactor

  // PostgreSQL layer for production
  val postgresLayer: ZLayer[Transactor[Task], Nothing, RideRepository] = ZLayer.fromFunction(
    PostgresRideRepository.apply
  )

  // Default layer (PostgreSQL with database transactor and migrations)
  val layer: ZLayer[Any, Throwable, RideRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
}
