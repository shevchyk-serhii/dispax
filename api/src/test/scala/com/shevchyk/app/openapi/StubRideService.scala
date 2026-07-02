package com.shevchyk.app.openapi

import com.shevchyk.core.domain.*
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import zio.{IO, ZIO}

/**
 * A RideService stub for endpoint specs whose endpoints never touch the ride service but need it in the environment.
 * Every method dies with NotImplementedError carrying the given tag, so an unexpected call fails the test loudly.
 */
object StubRideService:

  def notImplemented(tag: String): RideService =
    new RideService:
      private def notImpl = ZIO.die(new NotImplementedError(tag))

      def getRideById(rideId: RideId): IO[RideError, Ride]                                                            = notImpl
      def getFlightStatus(rideId: RideId): IO[RideError, Option[FlightStatusRow]]                                     = notImpl
      def reassignDriver(
          rideId: RideId,
          newDriverId: PersonId,
          overrideScheduleConflict: Boolean = false,
          allowPastRide: Boolean = false
      ): IO[RideError, Ride] = notImpl
      def assignDriver(
          rideId: RideId,
          driverId: PersonId,
          overrideScheduleConflict: Boolean = false
      ): IO[RideError, Ride] = notImpl
      def createRide(req: CreateRideRequest): IO[RideError, Ride]                                                     = notImpl
      def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]                                                = notImpl
      def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                          = notImpl
      def completeRide(rideId: RideId): IO[RideError, Ride]                                                           = notImpl
      def confirmRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                        = notImpl
      def rejectRide(rideId: RideId, driverId: PersonId, reason: String): IO[RideError, Ride]                         = notImpl
      def cancelRide(rideId: RideId, userId: PersonId, role: PersonRole): IO[RideError, Ride]                         = notImpl
      def cancelRideWithReason(
          rideId: RideId,
          userId: PersonId,
          role: PersonRole,
          req: CancelRideRequest,
          companyId: CompanyId
      ): IO[RideError, Ride] = notImpl
      def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]]                                 = notImpl
      def handOffToExternal(
          rideId: RideId,
          callerCompanyId: CompanyId,
          callerId: PersonId,
          req: HandOffRequest
      ): IO[RideError, Ride] = notImpl
      def createPartnerCompany(companyId: CompanyId, req: CreatePartnerCompanyRequest): IO[RideError, PartnerCompany] =
        notImpl
      def listPartnerCompanies(companyId: CompanyId): IO[RideError, List[PartnerCompany]]                             = notImpl
      def createExternalDriver(companyId: CompanyId, req: CreateExternalDriverRequest): IO[RideError, ExternalDriver] =
        notImpl
      def listExternalDrivers(companyId: CompanyId): IO[RideError, List[ExternalDriver]]                              = notImpl
      def updateRideStatus(
          rideId: RideId,
          req: UpdateRideStatusRequest,
          userId: PersonId,
          role: PersonRole
      ): IO[RideError, Ride] = notImpl
      def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]                                             = notImpl
      def getRidesByStatusAndCompany(status: RideStatus, companyId: CompanyId): IO[RideError, List[Ride]]             = notImpl
      def getDriverRides(driverId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]                         = notImpl
      def getClientRides(clientId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]                         = notImpl
      def getAllRides: IO[RideError, List[Ride]]                                                                      = notImpl
      def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]                                          = notImpl
      def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]]        = notImpl
      def getDriverRidesPaginated(
          driverId: PersonId,
          companyId: CompanyId,
          offset: Int,
          limit: Int
      ): IO[RideError, List[Ride]] = notImpl
      def updateRideDetails(
          rideId: RideId,
          req: UpdateRideDetailsRequest,
          userId: PersonId,
          role: PersonRole,
          cid: Option[CompanyId]
      ): IO[RideError, Ride] = notImpl
      def markPayment(
          rideId: RideId,
          ps: PaymentStatus,
          pm: Option[PaymentMethod]
      ): IO[RideError, Ride] = notImpl
      def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]]                                    = notImpl
      def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]                                = notImpl
      def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                            = notImpl
      def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                            = notImpl
      def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]                                        = notImpl
      def getDailyStats(
          companyId: CompanyId,
          days: Int
      ): IO[RideError, List[(String, Int, Int, Int)]] = notImpl
      def getDriverEarnings(
          driverId: PersonId,
          companyId: CompanyId,
          period: EarningsPeriod,
          anchorDate: java.time.LocalDate
      ): IO[RideError, DriverEarningsReport] = notImpl
      def setRidePrice(
          rideId: RideId,
          price: Double,
          userId: PersonId,
          userRole: PersonRole,
          companyId: CompanyId
      ): IO[RideError, Ride] = notImpl
      def getRidesByDrivers(
          driverIds: List[PersonId],
          from: Option[String],
          to: Option[String],
          companyId: CompanyId
      ): IO[RideError, List[Ride]] = notImpl
