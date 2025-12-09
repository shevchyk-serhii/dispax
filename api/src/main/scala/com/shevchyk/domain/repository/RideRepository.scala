package com.shevchyk.domain.repository

import com.shevchyk.domain.model.*
import zio.*



trait RideRepository:
  def save(ride: Ride): IO[RepositoryError, Ride]
  def findById(id: RideId): IO[RepositoryError, Option[Ride]]
  def findAll(): IO[RepositoryError, List[Ride]]
  def findByClientId(clientId: PersonId): IO[RepositoryError, List[Ride]]
  def findByDriverId(driverId: PersonId): IO[RepositoryError, List[Ride]]
  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Ride]]
  def findByStatus(status: RideStatus): IO[RepositoryError, List[Ride]]
  def update(ride: Ride): IO[RepositoryError, Option[Ride]]
  def delete(id: RideId): IO[RepositoryError, Boolean]

trait DriverRepository:
  def findById(id: PersonId): IO[RepositoryError, Option[Driver]]
  def findAvailableNear(location: Location, radius: Distance): IO[RepositoryError, List[Driver]]
  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Driver]]
  def updateStatus(driverId: PersonId, status: DriverStatus): IO[RepositoryError, Unit]
  def updateLocation(driverId: PersonId, location: Location): IO[RepositoryError, Unit]
  def save(driver: Driver): IO[RepositoryError, Driver]

trait PersonRepository:
  def findById(id: PersonId): IO[RepositoryError, Option[Person]]
  def findByEmail(email: String): IO[RepositoryError, Option[Person]]
  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Person]]
  def save(person: Person): IO[RepositoryError, Person]

trait TariffRepository:
  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, Option[Tariff]]
  def save(tariff: Tariff, companyId: CompanyId): IO[RepositoryError, Unit]


enum RepositoryError extends Exception:
  case DatabaseError(cause: Throwable)
  case NotFound(id: String)
  case ValidationError(msg: String)
  case UniqueConstraintViolation(field: String)
  case ConnectionError(msg: String)

  def message: String =
    this match
      case DatabaseError(cause)             => s"Database error: ${cause.getMessage}"
      case NotFound(id)                     => s"Entity not found with id: $id"
      case ValidationError(message)         => s"Validation error: $message"
      case UniqueConstraintViolation(field) => s"Unique constraint violation on field: $field"
      case ConnectionError(message)         => s"Connection error: $message"
