package com.shevchyk.ride.repository

import com.shevchyk.ride.domain.{AirportCheckpoint, DriverEarnings, Ride, RideStatus}
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
  // Paginated variants: ordering, LIMIT and OFFSET are applied in SQL so the full
  // table is never loaded into memory just to serve a single page.
  def findByCompanyIdPaginated(companyId: CompanyId, offset: Int, limit: Int): Task[List[Ride]]
  def findByDriverIdPaginated(driverId: PersonId, offset: Int, limit: Int): Task[List[Ride]]
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

  // ---------------------------------------------------------------------------
  // Platform-level (cross-tenant) analytics — SuperAdmin only.
  // No company_id parameter in any of these methods. Names contain `All` or
  // `Platform` to make the absence of tenant filtering explicit and grep-auditable.
  // These methods must only be called from SuperAdminApi after requireSuperAdmin().
  // ---------------------------------------------------------------------------

  /**
   * Count of rides per status, across ALL companies.
   */
  def countAllRidesByStatus(): Task[Map[String, Int]]

  /**
   * Sum of final_price_amount for Completed rides in [from, to) across ALL companies.
   */
  def sumAllRevenue(from: Instant, to: Instant): Task[BigDecimal]

  /**
   * Count of rides per company in [from, to), keyed by raw UUID.
   */
  def countRidesByCompany(from: Instant, to: Instant): Task[Map[java.util.UUID, Int]]

  /**
   * Sum of revenue per company in [from, to), keyed by raw UUID.
   */
  def sumRevenueByCompanyPlatform(from: Instant, to: Instant): Task[Map[java.util.UUID, BigDecimal]]

  // Update the airport checkpoint column for an arrival-transfer ride.
  // Returns true if the checkpoint was advanced (row was updated), false if it was already at the same
  // or a higher level (concurrent race lost). The SQL guard is authoritative; the in-memory pre-check
  // in AirportCheckpointService is a fast-fail optimisation only.
  def updateCheckpoint(rideId: RideId, checkpoint: AirportCheckpoint): Task[Boolean]
}

object RideRepository {
  import com.shevchyk.core.database.DatabaseConfig
  import doobie.Transactor

  val postgresLayer: ZLayer[Transactor[Task], Nothing, RideRepository] = ZLayer.fromFunction(
    PostgresRideRepository.apply
  )

  val layer: ZLayer[Any, Throwable, RideRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
}
