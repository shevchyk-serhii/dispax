package com.shevchyk.ride.repository

import com.shevchyk.ride.domain.{DriverEarnings, Ride, RideStatus}
import com.shevchyk.core.domain.{Location, RideId, PersonId, CompanyId}
import zio.*
import java.time.Instant

/**
 * Bucket granularity for the earnings chart.
 */
enum TimeBucket:
  case Hour, Day

trait RideRepository {
  def create(ride: Ride): Task[Ride]
  def findById(id: RideId): Task[Option[Ride]]
  def findByStatus(status: RideStatus): Task[List[Ride]]
  def findAll(): Task[List[Ride]]
  def findByClientId(clientId: PersonId): Task[List[Ride]]
  def findByDriverId(driverId: PersonId): Task[List[Ride]]
  def findByCompanyId(companyId: CompanyId): Task[List[Ride]]
  def update(ride: Ride): Task[Ride]
  def delete(id: RideId): Task[Unit]
  def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]]
  def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal]
  def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal]
  def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double]
  def countDailyStatsByCompany(companyId: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]]
  // Driver earnings aggregates for the period [from, to) with company isolation
  def earningsByDriver(driverId: PersonId, companyId: CompanyId, from: Instant, to: Instant): Task[DriverEarnings]

  // Revenue buckets for the chart (hourly or daily) for the period [from, to)
  def earningsBucketsByDriver(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant,
      bucket: TimeBucket
  ): Task[List[(Instant, BigDecimal)]]
  // Rides in Assigned status with pickup between from and to (for the reminder scheduler)
  def findAssignedRidesInWindow(from: Instant, to: Instant): Task[List[Ride]]
  // Reset sent reminders for a ride (when pickupDateTime changes)
  def clearReminders(rideId: RideId): Task[Unit]
}

object RideRepository {
  import com.shevchyk.core.database.DatabaseConfig
  import doobie.Transactor

  val postgresLayer: ZLayer[Transactor[Task], Nothing, RideRepository] = ZLayer.fromFunction(
    PostgresRideRepository.apply
  )

  val layer: ZLayer[Any, Throwable, RideRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
}
