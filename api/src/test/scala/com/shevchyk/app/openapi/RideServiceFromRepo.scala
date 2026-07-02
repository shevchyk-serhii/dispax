package com.shevchyk.app.openapi

import zio.{IO, ZLayer}

import com.shevchyk.core.domain.{CompanyId, PersonId, RideId, PersonRole}
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.RideRepository

/**
 * A [[RideService]] double whose `getRideById` reads from a backing [[RideRepository]] (so the checkpoint endpoint and
 * the real `AirportCheckpointService` see one consistent, mutating ride). Every other method dies loudly — the
 * checkpoint endpoints touch only `getRideById`. Used by the airport-checkpoint endpoint specs.
 */
object RideServiceFromRepo:

  def layer(repo: RideRepository): ZLayer[Any, Nothing, RideService] = ZLayer.succeed(
    new RideService:
      private def notImpl(m: String): Nothing = throw new NotImplementedError(s"RideServiceFromRepo.$m")

      def getRideById(rideId: RideId): IO[RideError, Ride] = repo
        .findById(rideId)
        .orDie
        .someOrFail(RideError.RideNotFound(rideId))

      def getFlightStatus(rideId: RideId): IO[RideError, Option[FlightStatusRow]]                                     = notImpl("getFlightStatus")
      def createRide(request: CreateRideRequest): IO[RideError, Ride]                                                 = notImpl("createRide")
      def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]                                                = notImpl("getRidesForUser")
      def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                          = notImpl("startRide")
      def completeRide(rideId: RideId): IO[RideError, Ride]                                                           = notImpl("completeRide")
      def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride]                     = notImpl(
        "cancelRide"
      )
      def cancelRideWithReason(
          rideId: RideId,
          userId: PersonId,
          userRole: PersonRole,
          req: CancelRideRequest,
          companyId: CompanyId
      ): IO[RideError, Ride] = notImpl("cancelRideWithReason")
      def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]]                                 = notImpl(
        "getCancellationStats"
      )
      def confirmRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                        = notImpl("confirmRide")
      def rejectRide(rideId: RideId, driverId: PersonId, reason: String): IO[RideError, Ride]                         = notImpl("rejectRide")
      def handOffToExternal(
          rideId: RideId,
          callerCompanyId: CompanyId,
          callerId: PersonId,
          req: HandOffRequest
      ): IO[RideError, Ride] = notImpl("handOffToExternal")
      def createPartnerCompany(companyId: CompanyId, req: CreatePartnerCompanyRequest): IO[RideError, PartnerCompany] =
        notImpl("createPartnerCompany")
      def listPartnerCompanies(companyId: CompanyId): IO[RideError, List[PartnerCompany]]                             = notImpl(
        "listPartnerCompanies"
      )
      def createExternalDriver(companyId: CompanyId, req: CreateExternalDriverRequest): IO[RideError, ExternalDriver] =
        notImpl("createExternalDriver")
      def listExternalDrivers(companyId: CompanyId): IO[RideError, List[ExternalDriver]]                              = notImpl(
        "listExternalDrivers"
      )
      def updateRideStatus(
          rideId: RideId,
          req: UpdateRideStatusRequest,
          userId: PersonId,
          role: PersonRole
      ): IO[RideError, Ride] = notImpl("updateRideStatus")
      def assignDriver(rideId: RideId, driverId: PersonId, overrideScheduleConflict: Boolean): IO[RideError, Ride]    =
        notImpl("assignDriver")
      def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]                                             = notImpl("getRidesByStatus")
      def getRidesByStatusAndCompany(status: RideStatus, companyId: CompanyId): IO[RideError, List[Ride]]             = notImpl(
        "getRidesByStatusAndCompany"
      )
      def getDriverRides(driverId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]                         = notImpl(
        "getDriverRides"
      )
      def getClientRides(clientId: PersonId, companyId: CompanyId): IO[RideError, List[Ride]]                         = notImpl(
        "getClientRides"
      )
      def getAllRides: IO[RideError, List[Ride]]                                                                      = notImpl("getAllRides")
      def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]                                          = notImpl("getRidesByCompany")
      def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]]        =
        notImpl("getRidesByCompanyPaginated")
      def getDriverRidesPaginated(
          driverId: PersonId,
          companyId: CompanyId,
          offset: Int,
          limit: Int
      ): IO[RideError, List[Ride]] = notImpl("getDriverRidesPaginated")
      def updateRideDetails(
          rideId: RideId,
          req: UpdateRideDetailsRequest,
          userId: PersonId,
          role: PersonRole,
          cid: Option[CompanyId]
      ): IO[RideError, Ride] = notImpl("updateRideDetails")
      def reassignDriver(
          rideId: RideId,
          newDriverId: PersonId,
          overrideScheduleConflict: Boolean,
          allowPastRide: Boolean = false
      ): IO[RideError, Ride] = notImpl("reassignDriver")
      def markPayment(rideId: RideId, ps: PaymentStatus, pm: Option[PaymentMethod]): IO[RideError, Ride]              = notImpl(
        "markPayment"
      )
      def getUnpaidCompletedRides(companyId: CompanyId): IO[RideError, List[Ride]]                                    = notImpl(
        "getUnpaidCompletedRides"
      )
      def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]                                = notImpl(
        "getRideCountsByStatus"
      )
      def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                            = notImpl("getTotalRevenue")
      def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                            = notImpl("getTodayRevenue")
      def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]                                        = notImpl(
        "getAvgAssignmentMinutes"
      )
      def getDailyStats(companyId: CompanyId, days: Int): IO[RideError, List[(String, Int, Int, Int)]]                = notImpl(
        "getDailyStats"
      )
      def getDriverEarnings(
          driverId: PersonId,
          companyId: CompanyId,
          period: EarningsPeriod,
          anchorDate: java.time.LocalDate
      ): IO[RideError, DriverEarningsReport] = notImpl("getDriverEarnings")
      def setRidePrice(
          rideId: RideId,
          price: Double,
          userId: PersonId,
          userRole: PersonRole,
          companyId: CompanyId
      ): IO[RideError, Ride] = notImpl("setRidePrice")
      def getRidesByDrivers(
          driverIds: List[PersonId],
          from: Option[String],
          to: Option[String],
          companyId: CompanyId
      ): IO[RideError, List[Ride]] = notImpl("getRidesByDrivers")
  )
