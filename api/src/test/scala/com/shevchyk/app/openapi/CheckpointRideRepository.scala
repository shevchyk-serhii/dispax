package com.shevchyk.app.openapi

import java.time.Instant
import java.util.UUID

import zio.{Ref, Task, UIO, ZIO}

import com.shevchyk.core.domain.{CompanyId, PersonId, RideId}
import com.shevchyk.ride.domain.{AirportCheckpoint, DriverEarnings, FlightStatusRow, PaymentMethod, Ride, RideStatus}
import com.shevchyk.ride.repository.{RideRepository, TimeBucket}

/**
 * A small stateful [[RideRepository]] double for the airport-checkpoint endpoint specs. It implements only the two
 * methods the real `AirportCheckpointService` touches:
 *
 *   - `findById` — so the endpoint and the service read the seeded ride and its current checkpoint, and
 *   - `updateCheckpoint` — the authoritative **forward-only** guard (advance only when the requested ordinal is
 *     strictly greater than the stored one, else return `false`). Mirroring the Postgres impl here is what makes a
 *     non-advancing mark fail with `InvalidOperation` in the service — the exact path the guest endpoint swallows as a
 *     204 no-op.
 *
 * The client/driver find methods (scoped and unscoped) also read the seeded map, for the specs that assert
 * company-scoped reads (e.g. the GDPR export).
 *
 * `ride`'s own `InMemoryRideRepository` is not on the api test classpath, hence this local double. Every other method
 * dies loudly so an accidental call surfaces immediately.
 */
final class CheckpointRideRepository private (rides: Ref[Map[RideId, Ride]]) extends RideRepository:
  private def notImpl(m: String): Nothing = throw new NotImplementedError(s"CheckpointRideRepository.$m")

  override def findById(id: RideId): Task[Option[Ride]] = rides.get.map(_.get(id))

  override def updateCheckpoint(rideId: RideId, checkpoint: AirportCheckpoint): Task[Boolean] = rides.modify { m =>
    m.get(rideId) match
      case Some(ride) if checkpoint.ordinal > ride.airportCheckpoint.map(_.ordinal).getOrElse(-1) =>
        (true, m.updated(rideId, ride.copy(airportCheckpoint = Some(checkpoint))))
      case _                                                                                      => (false, m)
  }

  def create(ride: Ride): Task[Ride]                     = notImpl("create")
  def findByStatus(status: RideStatus): Task[List[Ride]] = notImpl("findByStatus")
  def findAll(): Task[List[Ride]]                        = notImpl("findAll")

  // Client/driver finds (scoped and unscoped) read the seeded map — used by the GDPR export spec
  // to assert the company-scoped variants are what the endpoint actually calls.
  def findByClientId(clientId: PersonId): Task[List[Ride]] = rides.get.map(
    _.values.filter(_.clientId == clientId).toList
  )

  def findByDriverId(driverId: PersonId): Task[List[Ride]] = rides.get.map(
    _.values.filter(_.driverId.contains(driverId)).toList
  )

  def findByDriverIdAndCompany(driverId: PersonId, companyId: CompanyId): Task[List[Ride]] = rides.get.map(
    _.values.filter(r => r.driverId.contains(driverId) && r.companyId == companyId).toList
  )

  def findByClientIdAndCompany(clientId: PersonId, companyId: CompanyId): Task[List[Ride]] = rides.get.map(
    _.values.filter(r => r.clientId == clientId && r.companyId == companyId).toList
  )

  def findByStatusAndCompany(status: RideStatus, companyId: CompanyId): Task[List[Ride]] = notImpl(
    "findByStatusAndCompany"
  )
  def findByCompanyId(companyId: CompanyId): Task[List[Ride]]                            = notImpl("findByCompanyId")

  def findByCompanyIdPaginated(companyId: CompanyId, offset: Int, limit: Int): Task[List[Ride]] = notImpl(
    "findByCompanyIdPaginated"
  )

  def findByDriverIdPaginated(driverId: PersonId, offset: Int, limit: Int): Task[List[Ride]] = notImpl(
    "findByDriverIdPaginated"
  )

  def findByDriverIdAndCompanyPaginated(
      driverId: PersonId,
      companyId: CompanyId,
      offset: Int,
      limit: Int
  ): Task[List[Ride]] = notImpl("findByDriverIdAndCompanyPaginated")
  def update(ride: Ride): Task[Ride]                                                         = notImpl("update")
  def updateIfStatus(ride: Ride, expectedStatuses: Set[RideStatus]): Task[Boolean]           = notImpl("updateIfStatus")

  def markPaidIfCompleted(rideId: RideId, paymentMethod: Option[PaymentMethod]): Task[Boolean] = notImpl(
    "markPaidIfCompleted"
  )
  def delete(id: RideId, companyId: CompanyId): Task[Unit]                                     = notImpl("delete")

  def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]] = notImpl(
    "countByCompanyGroupedByStatus"
  )
  def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                 = notImpl("sumRevenueByCompany")

  def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal] = notImpl(
    "sumTodayRevenueByCompany"
  )

  def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double] = notImpl(
    "avgAssignmentMinutesByCompany"
  )

  def countDailyStatsByCompany(companyId: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]] = notImpl(
    "countDailyStatsByCompany"
  )

  def earningsByDriver(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): Task[DriverEarnings] = notImpl("earningsByDriver")

  def earningsBucketsByDriver(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant,
      bucket: TimeBucket
  ): Task[List[(Instant, BigDecimal)]] = notImpl("earningsBucketsByDriver")

  def findAssignedRidesInWindow(from: Instant, to: Instant): Task[List[Ride]] = notImpl(
    "findAssignedRidesInWindow"
  )

  def findActiveRidesInWindow(from: Instant, to: Instant): Task[List[Ride]] = notImpl(
    "findActiveRidesInWindow"
  )

  def findRidesNeedingConfirmation(from: Instant, to: Instant): Task[List[Ride]] = notImpl(
    "findRidesNeedingConfirmation"
  )

  def findByDriverIdInWindow(driverId: PersonId, from: Instant, to: Instant): Task[List[Ride]] = notImpl(
    "findByDriverIdInWindow"
  )
  def clearReminders(rideId: RideId): Task[Unit]                                               = notImpl("clearReminders")
  def countAllRidesByStatus(): Task[Map[String, Int]]                                          = notImpl("countAllRidesByStatus")
  def sumAllRevenue(from: Instant, to: Instant): Task[BigDecimal]                              = notImpl("sumAllRevenue")
  def countRidesByCompany(from: Instant, to: Instant): Task[Map[UUID, Int]]                    = notImpl("countRidesByCompany")

  def sumRevenueByCompanyPlatform(from: Instant, to: Instant): Task[Map[UUID, BigDecimal]] = notImpl(
    "sumRevenueByCompanyPlatform"
  )

  def updateFlightStatus(
      rideId: RideId,
      gate: Option[String],
      terminal: Option[String],
      flightStatus: Option[String],
      flightTime: Option[Instant],
      scheduledTime: Option[Instant],
      departureTime: Option[Instant]
  ): Task[Boolean] = notImpl("updateFlightStatus")
  def findFlightStatus(rideId: RideId): Task[Option[FlightStatusRow]]                      = notImpl("findFlightStatus")
  def findFlightStatusFor(rideIds: List[RideId]): Task[Map[RideId, FlightStatusRow]]       = ZIO.succeed(Map.empty)

object CheckpointRideRepository:

  /**
   * Build a repository pre-seeded with the given rides (keyed by their own id).
   */
  def make(seed: Ride*): UIO[CheckpointRideRepository] = Ref
    .make(seed.map(r => r.id -> r).toMap)
    .map(new CheckpointRideRepository(_))
