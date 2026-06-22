package com.shevchyk.schedule.repository

import com.shevchyk.core.domain.{CompanyId, DriverUnavailabilityId, PersonId}
import com.shevchyk.core.database.DatabaseConfig
import com.shevchyk.schedule.domain.DriverUnavailability
import doobie.Transactor
import zio.*
import java.time.Instant

trait DriverUnavailabilityRepository:
  def create(unavailability: DriverUnavailability): Task[DriverUnavailability]
  def findById(id: DriverUnavailabilityId): Task[Option[DriverUnavailability]]
  def findByDriver(driverId: PersonId, companyId: CompanyId): Task[List[DriverUnavailability]]
  def findByCompanyAndRange(companyId: CompanyId, from: Instant, to: Instant): Task[List[DriverUnavailability]]

  /**
   * Returns all unavailability windows for the driver+company that overlap the half-open interval [from, to). SQL
   * half-open overlap: from_time < to AND from < to_time
   */
  def findOverlapping(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): Task[List[DriverUnavailability]]

  /**
   * Tenant-scoped delete: only removes the record when it belongs to both driverId and companyId.
   */
  def delete(id: DriverUnavailabilityId, driverId: PersonId, companyId: CompanyId): Task[Unit]

object DriverUnavailabilityRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, DriverUnavailabilityRepository] = ZLayer.fromFunction(
    PostgresDriverUnavailabilityRepository.apply
  )

  val layer: ZLayer[Any, Throwable, DriverUnavailabilityRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
