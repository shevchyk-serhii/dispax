package com.shevchyk.infrastructure.repository.postgres

import com.shevchyk.domain.repository.*
import com.shevchyk.infrastructure.database.DatabaseService
import zio.*

object RepositoryLayers:

  val rideRepository: ZLayer[DatabaseService, Nothing, RideRepository] = ZLayer.fromFunction((db: DatabaseService) =>
    DoobieRideRepository(db.xa)
  )

  val personRepository: ZLayer[DatabaseService, Nothing, PersonRepository] = ZLayer.fromFunction(
    (db: DatabaseService) => DoobiePersonRepository(db.xa)
  )

  val driverRepository: ZLayer[DatabaseService, Nothing, DriverRepository] = ZLayer.fromFunction(
    (db: DatabaseService) => DoobieDriverRepository(db.xa)
  )

  val tariffRepository: ZLayer[DatabaseService, Nothing, TariffRepository] = ZLayer.fromFunction(
    (db: DatabaseService) => DoobieTariffRepository(db.xa)
  )

  val all: ZLayer[DatabaseService, Nothing, RideRepository & PersonRepository & DriverRepository & TariffRepository] =
    rideRepository ++ personRepository ++ driverRepository ++ tariffRepository
