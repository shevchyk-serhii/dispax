package com.shevchyk.driver.infrastructure

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{EventHub, GeofenceService, ActiveRideInfo}
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.driver.application.DriverLocationService
import com.shevchyk.driver.infrastructure.http.DriverRoutes
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.InMemoryRideRepository
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID

object DriverRoutesSpec extends ZIOSpecDefault {

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-at-least-256-bits-long-for-hmac-sha256-algorithm-padding",
      issuer = "test", audience = "test",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
    )
  )
  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private val driverId     = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val dispatcherId = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val companyId    = UUID.fromString("00000003-0000-0000-0000-000000000003")

  private def token(role: PersonRole, uid: UUID, cid: Option[UUID] = Some(companyId)): ZIO[JwtService, Throwable, String] =
    ZIO.serviceWithZIO[JwtService](_.generateToken(
      Person(PersonId(uid), "Test", "test@example.com", role, cid.map(CompanyId.apply))
    ))

  private val noopGeofenceService: ZLayer[Any, Nothing, GeofenceService] = ZLayer.succeed(
    new GeofenceService:
      def checkDriverLocation(d: PersonId, c: CompanyId, lat: Double, lng: Double): UIO[List[GeofenceAlert]] = ZIO.succeed(Nil)
      def checkClientProximity(d: PersonId, lat: Double, lng: Double, rides: List[ActiveRideInfo]): UIO[Unit] = ZIO.unit
  )

  private val noopPersonRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(new PersonRepository {
    def create(p: Person): Task[Person]                                             = ZIO.succeed(p)
    def findById(id: PersonId): Task[Option[Person]]                               = ZIO.succeed(None)
    def findByEmail(email: String): Task[Option[Person]]                           = ZIO.succeed(None)
    def findByRole(role: PersonRole): Task[List[Person]]                           = ZIO.succeed(Nil)
    def findByRoleAndCompany(role: PersonRole, cid: CompanyId): Task[List[Person]] = ZIO.succeed(Nil)
    def findByCompanyId(cid: CompanyId): Task[List[Person]]                        = ZIO.succeed(Nil)
    def findAll(): Task[List[Person]]                                               = ZIO.succeed(Nil)
    def update(p: Person): Task[Person]                                            = ZIO.succeed(p)
    def delete(id: PersonId): Task[Unit]                                           = ZIO.unit
    def findByStatus(s: UserStatus): Task[List[Person]]                            = ZIO.succeed(Nil)
    def searchByQuery(q: String): Task[List[Person]]                               = ZIO.succeed(Nil)
    def updateLastLogin(id: PersonId): Task[Unit]                                  = ZIO.unit
    def findByClientCompany(cid: ClientCompanyId): Task[List[Person]]             = ZIO.succeed(Nil)
  })

  private val driverLocationServiceLayer =
    (com.shevchyk.driver.application.DriverLocationServiceSpec.InMemoryDriverLocationRepository.layer ++
      EventHub.layer ++
      noopGeofenceService ++
      InMemoryRideRepository.layer ++
      noopPersonRepo) >>>
    DriverLocationService.layer

  private val noopRideServiceLayer: ZLayer[Any, Nothing, RideService] = ZLayer.succeed {
    new RideService {
      def getRideById(rideId: RideId): IO[RideError, Ride]                                                                            = ZIO.fail(RideError.RideNotFound(rideId))
      def createRide(request: CreateRideRequest): IO[RideError, Ride]                                                                 = ZIO.fail(RideError.ValidationError("noop"))
      def getRidesForUser(userId: PersonId): IO[RideError, List[Ride]]                                                                = ZIO.succeed(Nil)
      def startRide(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                                          = ZIO.fail(RideError.RideNotFound(rideId))
      def completeRide(rideId: RideId): IO[RideError, Ride]                                                                           = ZIO.fail(RideError.RideNotFound(rideId))
      def cancelRide(rideId: RideId, userId: PersonId, userRole: PersonRole): IO[RideError, Ride]                                     = ZIO.fail(RideError.RideNotFound(rideId))
      def cancelRideWithReason(rideId: RideId, userId: PersonId, userRole: PersonRole, req: CancelRideRequest): IO[RideError, Ride]   = ZIO.fail(RideError.RideNotFound(rideId))
      def getCancellationStats(companyId: CompanyId): IO[RideError, Map[String, Int]]                                                 = ZIO.succeed(Map.empty)
      def updateRideStatus(rideId: RideId, req: UpdateRideStatusRequest, userId: PersonId, userRole: PersonRole): IO[RideError, Ride]  = ZIO.fail(RideError.RideNotFound(rideId))
      def assignDriver(rideId: RideId, driverId: PersonId): IO[RideError, Ride]                                                       = ZIO.fail(RideError.RideNotFound(rideId))
      def getRidesByStatus(status: RideStatus): IO[RideError, List[Ride]]                                                             = ZIO.succeed(Nil)
      def getDriverRides(driverId: PersonId): IO[RideError, List[Ride]]                                                               = ZIO.succeed(Nil)
      def getClientRides(clientId: PersonId): IO[RideError, List[Ride]]                                                               = ZIO.succeed(Nil)
      def getAllRides: IO[RideError, List[Ride]]                                                                                       = ZIO.succeed(Nil)
      def getRidesByCompany(companyId: CompanyId): IO[RideError, List[Ride]]                                                          = ZIO.succeed(Nil)
      def getRidesByCompanyPaginated(companyId: CompanyId, offset: Int, limit: Int): IO[RideError, List[Ride]]                        = ZIO.succeed(Nil)
      def getDriverRidesPaginated(driverId: PersonId, offset: Int, limit: Int): IO[RideError, List[Ride]]                             = ZIO.succeed(Nil)
      def updateRideDetails(rideId: RideId, req: UpdateRideDetailsRequest, userId: PersonId, userRole: PersonRole, companyId: Option[CompanyId]): IO[RideError, Ride] = ZIO.fail(RideError.RideNotFound(rideId))
      def reassignDriver(rideId: RideId, newDriverId: PersonId): IO[RideError, Ride]                                                  = ZIO.fail(RideError.RideNotFound(rideId))
      def markPayment(rideId: RideId, paymentStatus: PaymentStatus, paymentMethod: Option[PaymentMethod]): IO[RideError, Ride]        = ZIO.fail(RideError.RideNotFound(rideId))
      def getUnpaidCompletedRides: IO[RideError, List[Ride]]                                                                          = ZIO.succeed(Nil)
      def getRideCountsByStatus(companyId: CompanyId): IO[RideError, Map[String, Int]]                                                = ZIO.succeed(Map.empty)
      def getTotalRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                                            = ZIO.succeed(BigDecimal(0))
      def getTodayRevenue(companyId: CompanyId): IO[RideError, BigDecimal]                                                            = ZIO.succeed(BigDecimal(0))
      def getAvgAssignmentMinutes(companyId: CompanyId): IO[RideError, Double]                                                        = ZIO.succeed(0.0)
      def getDailyStats(companyId: CompanyId, days: Int): IO[RideError, List[(String, Int, Int, Int)]]                                = ZIO.succeed(Nil)
    }
  }

  private val testLayers = driverLocationServiceLayer ++ noopRideServiceLayer ++ testJwtService

  private def run(req: Request): ZIO[DriverLocationService & RideService & JwtService, Nothing, Response] =
    DriverRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  def spec = suite("DriverRoutes")(

    suite("PUT /api/drivers/:id/location")(
      test("driver can update own location (204)") {
        val body = """{"latitude":48.1351,"longitude":11.5820}"""
        for {
          tok      <- token(PersonRole.Driver, driverId)
          response <- run(Request.put(
                        URL.decode(s"/api/drivers/$driverId/location").toOption.get,
                        Body.fromString(body)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NoContent)
      }.provide(testLayers),

      test("returns 401 without token") {
        val body = """{"latitude":48.1351,"longitude":11.5820}"""
        run(Request.put(URL.decode(s"/api/drivers/$driverId/location").toOption.get, Body.fromString(body)))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers),

      test("returns 400 for invalid UUID") {
        val body = """{"latitude":48.1351,"longitude":11.5820}"""
        for {
          tok      <- token(PersonRole.Driver, driverId)
          response <- run(Request.put(
                        URL.decode("/api/drivers/not-a-uuid/location").toOption.get,
                        Body.fromString(body)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.BadRequest)
      }.provide(testLayers)
    ),

    suite("PUT /api/drivers/:id/availability")(
      test("driver can set own availability to Available (204)") {
        val body = """{"status":"Available"}"""
        for {
          tok      <- token(PersonRole.Driver, driverId)
          response <- run(Request.put(
                        URL.decode(s"/api/drivers/$driverId/availability").toOption.get,
                        Body.fromString(body)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NoContent)
      }.provide(testLayers),

      test("driver can set own availability to Offline (204)") {
        val body = """{"status":"Offline"}"""
        for {
          tok      <- token(PersonRole.Driver, driverId)
          response <- run(Request.put(
                        URL.decode(s"/api/drivers/$driverId/availability").toOption.get,
                        Body.fromString(body)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NoContent)
      }.provide(testLayers),

      test("returns 500 for invalid status value") {
        val body = """{"status":"InvalidStatus"}"""
        for {
          tok      <- token(PersonRole.Driver, driverId)
          response <- run(Request.put(
                        URL.decode(s"/api/drivers/$driverId/availability").toOption.get,
                        Body.fromString(body)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.InternalServerError)
      }.provide(testLayers),

      test("returns 401 without token") {
        val body = """{"status":"Available"}"""
        run(Request.put(URL.decode(s"/api/drivers/$driverId/availability").toOption.get, Body.fromString(body)))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    ),

    suite("GET /api/drivers/:id/availability")(
      test("driver can get own availability (200)") {
        for {
          tok      <- token(PersonRole.Driver, driverId)
          response <- run(Request.get(URL.decode(s"/api/drivers/$driverId/availability").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("secretary can get driver availability (200)") {
        for {
          tok      <- token(PersonRole.Secretary, dispatcherId)
          response <- run(Request.get(URL.decode(s"/api/drivers/$driverId/availability").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.get(URL.decode(s"/api/drivers/$driverId/availability").toOption.get))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    ),

    suite("GET /api/drivers/available")(
      test("dispatcher gets available drivers (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.get(URL.decode("/api/drivers/available").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, UUID.randomUUID())
          response <- run(Request.get(URL.decode("/api/drivers/available").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.get(URL.decode("/api/drivers/available").toOption.get))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    )
  )
}
