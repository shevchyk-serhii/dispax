package com.shevchyk.app.openapi

import java.time.Instant
import java.util.UUID

import zio.{Task, ZIO, ZLayer}

import com.shevchyk.core.domain.{CompanyId, PersonId, RideId}
import com.shevchyk.ride.domain.{AirportCheckpoint, DriverEarnings, FlightStatusRow, PaymentMethod, Ride, RideStatus}
import com.shevchyk.ride.repository.{RideRepository, TimeBucket}

/**
 * A no-op [[RideRepository]] for route specs that build the full `RideApi.RideEnv` but never exercise the repository
 * (e.g. assign/confirm isolation specs). Every method dies with NotImplementedError so an accidental call is loud;
 * override only what a spec needs. `ride`'s own `InMemoryRideRepository` is not on the api test classpath, hence this
 * local stub.
 */
object StubRideRepository:

  val layer: ZLayer[Any, Nothing, RideRepository] = ZLayer.succeed(new RideRepository:
    private def notImpl(m: String): Nothing = throw new NotImplementedError(s"StubRideRepository.$m")

    def create(ride: Ride): Task[Ride]                                                                 = notImpl("create")
    def findById(id: RideId): Task[Option[Ride]]                                                       = notImpl("findById")
    def findByStatus(status: RideStatus): Task[List[Ride]]                                             = notImpl("findByStatus")
    def findAll(): Task[List[Ride]]                                                                    = notImpl("findAll")
    def findByClientId(clientId: PersonId): Task[List[Ride]]                                           = notImpl("findByClientId")
    def findByDriverId(driverId: PersonId): Task[List[Ride]]                                           = notImpl("findByDriverId")
    def findByDriverIdAndCompany(driverId: PersonId, companyId: CompanyId): Task[List[Ride]]           = notImpl(
      "findByDriverIdAndCompany"
    )
    def findByClientIdAndCompany(clientId: PersonId, companyId: CompanyId): Task[List[Ride]]           = notImpl(
      "findByClientIdAndCompany"
    )
    def findByStatusAndCompany(status: RideStatus, companyId: CompanyId): Task[List[Ride]]             = notImpl(
      "findByStatusAndCompany"
    )
    def findByCompanyId(companyId: CompanyId): Task[List[Ride]]                                        = notImpl("findByCompanyId")
    def findByCompanyIdPaginated(companyId: CompanyId, offset: Int, limit: Int): Task[List[Ride]]      = notImpl(
      "findByCompanyIdPaginated"
    )
    def findByDriverIdPaginated(driverId: PersonId, offset: Int, limit: Int): Task[List[Ride]]         = notImpl(
      "findByDriverIdPaginated"
    )
    def findByDriverIdAndCompanyPaginated(
        driverId: PersonId,
        companyId: CompanyId,
        offset: Int,
        limit: Int
    ): Task[List[Ride]] = notImpl("findByDriverIdAndCompanyPaginated")
    def update(ride: Ride): Task[Ride]                                                                 = notImpl("update")
    def updateIfStatus(ride: Ride, expectedStatuses: Set[RideStatus]): Task[Boolean]                   = notImpl("updateIfStatus")
    def markPaidIfCompleted(rideId: RideId, paymentMethod: Option[PaymentMethod]): Task[Boolean]       = notImpl(
      "markPaidIfCompleted"
    )
    def delete(id: RideId, companyId: CompanyId): Task[Unit]                                           = notImpl("delete")
    def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]]                    = notImpl(
      "countByCompanyGroupedByStatus"
    )
    def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                                    = notImpl("sumRevenueByCompany")
    def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal]                               = notImpl("sumTodayRevenueByCompany")
    def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double]                              = notImpl("avgAssignmentMinutesByCompany")
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
    def findAssignedRidesInWindow(from: Instant, to: Instant): Task[List[Ride]]                        = notImpl("findAssignedRidesInWindow")
    def findActiveRidesInWindow(from: Instant, to: Instant): Task[List[Ride]]                          = notImpl("findActiveRidesInWindow")
    def findRidesNeedingConfirmation(from: Instant, to: Instant): Task[List[Ride]]                     = notImpl(
      "findRidesNeedingConfirmation"
    )
    def clearReminders(rideId: RideId): Task[Unit]                                                     = notImpl("clearReminders")
    def countAllRidesByStatus(): Task[Map[String, Int]]                                                = notImpl("countAllRidesByStatus")
    def sumAllRevenue(from: Instant, to: Instant): Task[BigDecimal]                                    = notImpl("sumAllRevenue")
    def countRidesByCompany(from: Instant, to: Instant): Task[Map[UUID, Int]]                          = notImpl("countRidesByCompany")
    def sumRevenueByCompanyPlatform(from: Instant, to: Instant): Task[Map[UUID, BigDecimal]]           = notImpl(
      "sumRevenueByCompanyPlatform"
    )
    def updateCheckpoint(rideId: RideId, checkpoint: AirportCheckpoint): Task[Boolean]                 = notImpl("updateCheckpoint")
    def updateFlightStatus(
        rideId: RideId,
        gate: Option[String],
        terminal: Option[String],
        flightStatus: Option[String],
        flightTime: Option[Instant],
        scheduledTime: Option[Instant],
        departureTime: Option[Instant]
    ): Task[Boolean] = notImpl("updateFlightStatus")
    def findFlightStatus(rideId: RideId): Task[Option[FlightStatusRow]]                                = notImpl("findFlightStatus")
    def findFlightStatusFor(rideIds: List[RideId]): Task[Map[RideId, FlightStatusRow]]                 = ZIO.succeed(Map.empty)
  )
