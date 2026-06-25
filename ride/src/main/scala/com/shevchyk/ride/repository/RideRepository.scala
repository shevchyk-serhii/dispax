package com.shevchyk.ride.repository

import com.shevchyk.ride.domain.{AirportCheckpoint, DriverEarnings, PaymentMethod, Ride, RideStatus}
import com.shevchyk.core.domain.{RideId, PersonId, CompanyId}
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
  // Tenant-scoped variants: the same lookups but constrained to a single company.
  // Use these whenever the caller acts within one tenant (e.g. a dispatcher listing
  // a driver's/client's rides). The unscoped variants above must only be used where
  // company isolation is enforced elsewhere (status machine on an already-loaded ride,
  // GDPR self-export, SuperAdmin) — never with an id taken straight from the request path.
  def findByDriverIdAndCompany(driverId: PersonId, companyId: CompanyId): Task[List[Ride]]
  def findByClientIdAndCompany(clientId: PersonId, companyId: CompanyId): Task[List[Ride]]
  def findByStatusAndCompany(status: RideStatus, companyId: CompanyId): Task[List[Ride]]
  def findByCompanyId(companyId: CompanyId): Task[List[Ride]]
  // Paginated variants: ordering, LIMIT and OFFSET are applied in SQL so the full
  // table is never loaded into memory just to serve a single page.
  def findByCompanyIdPaginated(companyId: CompanyId, offset: Int, limit: Int): Task[List[Ride]]
  def findByDriverIdPaginated(driverId: PersonId, offset: Int, limit: Int): Task[List[Ride]]

  def findByDriverIdAndCompanyPaginated(
      driverId: PersonId,
      companyId: CompanyId,
      offset: Int,
      limit: Int
  ): Task[List[Ride]]
  def update(ride: Ride): Task[Ride]
  // Atomic compare-and-set on the ride status: persists `ride` only if the row's current
  // status is still one of `expectedStatuses`. Returns true on success, false if another
  // concurrent transaction already moved the ride out of those statuses. Used to make
  // driver (re)assignment safe against the read-modify-write race between two dispatchers.
  def updateIfStatus(ride: Ride, expectedStatuses: Set[RideStatus]): Task[Boolean]
  // Field-level atomic compare-and-set for the "mark paid" transition: flips payment_status to
  // 'Paid', stamps payment_method and paid_at = NOW() only when the row is still Completed and not
  // already Paid. Returns true if this call won the race (the row was updated), false otherwise
  // (ride is not Completed, or another concurrent markPaid already won). Closes the lost-update
  // window that a read-modify-write update leaves open between two concurrent markPayment(Paid) calls.
  def markPaidIfCompleted(rideId: RideId, paymentMethod: Option[PaymentMethod]): Task[Boolean]
  // Tenant-scoped delete: only removes the ride when it belongs to `companyId`.
  def delete(id: RideId, companyId: CompanyId): Task[Unit]
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
  // Rides in Assigned status with a driver assigned and pickup in [from, to) — used by the
  // morning confirmation-request scheduler to know which rides still need a confirmation push.
  def findRidesNeedingConfirmation(from: Instant, to: Instant): Task[List[Ride]]
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
