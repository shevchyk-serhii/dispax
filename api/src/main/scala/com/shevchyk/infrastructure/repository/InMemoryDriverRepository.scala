package com.shevchyk.infrastructure.repository

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.{DriverRepository, RepositoryError}
import zio.*

case class InMemoryDriverRepository(storage: Ref[Map[PersonId, Driver]]) extends DriverRepository:

  override def findById(id: PersonId): IO[RepositoryError, Option[Driver]] = storage.get.map(_.get(id))

  override def findAvailableNear(location: Location, radius: Distance): IO[RepositoryError, List[Driver]] = storage.get
    .map { drivers =>
      drivers.values.filter { driver =>
        driver.isAvailableForRide && driver.distanceFromLocation(location) < radius
      }.toList
    }

  override def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Driver]] = storage.get.map(
    _.values.filter(_.companyId == companyId).toList
  )

  override def updateStatus(driverId: PersonId, status: DriverStatus): IO[RepositoryError, Unit] = storage.update {
    drivers =>
      drivers.get(driverId) match
        case Some(driver) => drivers + (driverId -> driver.copy(status = status))
        case None         => drivers
  }

  override def updateLocation(driverId: PersonId, location: Location): IO[RepositoryError, Unit] = storage.update {
    drivers =>
      drivers.get(driverId) match
        case Some(driver) => drivers + (driverId -> driver.copy(currentLocation = location))
        case None         => drivers
  }

  override def save(driver: Driver): IO[RepositoryError, Driver] = storage.update(_ + (driver.id -> driver)).as(driver)

object InMemoryDriverRepository:

  val layer: ZLayer[Any, Nothing, DriverRepository] = ZLayer.fromZIO(
    Ref.make(mockDrivers).map(InMemoryDriverRepository(_))
  )

  private val mockDrivers: Map[PersonId, Driver] = Map(
    PersonId(1) -> Driver(
      id = PersonId(1),
      name = "John Driver",
      currentLocation = Location("Munich Center", Some(48.1351), Some(11.5820)),
      status = DriverStatus.Available,
      companyId = CompanyId(1)
    ),
    PersonId(5) -> Driver(
      id = PersonId(5),
      name = "Max Driver",
      currentLocation = Location("Munich Airport", Some(48.3538), Some(11.7861)),
      status = DriverStatus.Available,
      companyId = CompanyId(1)
    ),
    PersonId(6) -> Driver(
      id = PersonId(6),
      name = "Anna Driver",
      currentLocation = Location("Munich South", Some(48.1000), Some(11.5500)),
      status = DriverStatus.Busy,
      companyId = CompanyId(1)
    )
  )
