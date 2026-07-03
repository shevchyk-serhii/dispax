package com.shevchyk.app.openapi

import java.time.Instant
import java.util.UUID

import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import com.shevchyk.core.application.GeocodingService
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.driver.application.{DriverLocationService, HereRoutingService}
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.driver.openapi.DriverApi
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.ClientLocationRepository

/**
 * Endpoint-level tests for GET /api/rides/{rideId}/driver-location on DriverApi.
 *
 * Regression coverage for the IDOR audit finding: the handler only checked company isolation, so ANY authenticated
 * company user (e.g. an unrelated CLIENT) could read the live coordinates, approach flag, distance and ETA of the
 * driver of ANY ride in their company. The endpoint must be restricted to the ride's parties (its client, its assigned
 * driver) and staff (DISPATCHER/SECRETARY).
 *
 * Runs the REAL `DriverApi.serverEndpoints` through `ZioHttpInterpreter` with a seeded ride and a stub location
 * service.
 */
object DriverProximityAccessSpec extends ZIOSpecDefault:

  // -- Fixtures ------------------------------------------------------------
  private val companyAId    = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val clientId      = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val strangerId    = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000002"))
  private val driverId      = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val otherDriverId = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000002"))
  private val rideId        = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))

  private def assignedRide(): Ride = Ride(
    id = rideId,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyAId,
    driverId = Some(driverId),
    status = RideStatus.Assigned,
    pickupLocation = Location("Munich Airport", Some(48.3538), Some(11.7861)),
    dropoffLocation = Location("Munich City"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    requestTime = Instant.now()
  )

  // -- Stub layers ----------------------------------------------------------
  private val stubLocationService: ZLayer[Any, Nothing, DriverLocationService] = ZLayer.succeed(
    new DriverLocationService:
      def updateLocation(driverId: PersonId, latitude: Double, longitude: Double) = ZIO.die(
        new NotImplementedError("stub")
      )
      def getLocation(driverId: PersonId)                                         = ZIO.some(DriverLocation(driverId, 48.20, 11.60))
      def updateAvailability(driverId: PersonId, status: String)                  = ZIO.die(new NotImplementedError("stub"))
      def getAvailability(driverId: PersonId)                                     = ZIO.die(new NotImplementedError("stub"))
      def getAvailableDrivers(companyId: CompanyId)                               = ZIO.succeed(Nil)
  )

  private val stubHereRouting: ZLayer[Any, Nothing, HereRoutingService] = ZLayer.succeed(
    new HereRoutingService:
      def getEtaMinutes(originLat: Double, originLng: Double, destLat: Double, destLng: Double) = ZIO.some(7)
  )

  private val stubClientLocationRepo: ZLayer[Any, Nothing, ClientLocationRepository] = ZLayer.succeed(
    new ClientLocationRepository:
      def updateLocation(rideId: RideId, clientId: PersonId, latitude: Double, longitude: Double) = ZIO.unit
      def getLocation(rideId: RideId)                                                             = ZIO.none
  )

  private val stubPersonRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      def create(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.none
      def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]]                       = ZIO.none
      def findByEmail(email: String): Task[Option[Person]]                                                   = ZIO.none
      def findByRole(role: PersonRole): Task[List[Person]]                                                   = ZIO.succeed(Nil)
      def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]]                   = ZIO.succeed(Nil)
      def findByCompanyId(companyId: CompanyId): Task[List[Person]]                                          = ZIO.succeed(Nil)
      def findAll(): Task[List[Person]]                                                                      = ZIO.succeed(Nil)
      def update(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def delete(id: PersonId): Task[Unit]                                                                   = ZIO.unit
      def deleteInCompany(id: PersonId, companyId: CompanyId): Task[Unit]                                    = ZIO.unit
      def findByStatus(status: UserStatus): Task[List[Person]]                                               = ZIO.succeed(Nil)
      def searchByQuery(query: String): Task[List[Person]]                                                   = ZIO.succeed(Nil)
      def updateLastLogin(id: PersonId): Task[Unit]                                                          = ZIO.unit
      def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]                          = ZIO.succeed(Nil)
      def upsertDriverRow(personId: PersonId): Task[Unit]                                                    = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                       = ZIO.none
      def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] = ZIO.unit
      def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                                       = ZIO.unit
  )

  private def buildLayers(repo: CheckpointRideRepository): ZLayer[Any, Throwable, DriverApi.DriverEnv] =
    TestJwt.serviceLayer ++
      RideServiceFromRepo.layer(repo) ++
      stubLocationService ++
      stubHereRouting ++
      GeocodingService.noop ++
      stubClientLocationRepo ++
      stubPersonRepo

  private def run(req: Request, layers: ZLayer[Any, Throwable, DriverApi.DriverEnv]): ZIO[Any, Throwable, Response] =
    ZioHttpInterpreter()
      .toHttp(DriverApi.serverEndpoints)
      .run(req)
      .either
      .map {
        case Left(r)  => r.merge
        case Right(r) => r
      }
      .provideLayer(layers)

  private def proximityReq(token: String): Request = Request
    .get(URL.decode(s"/api/rides/${rideId.value}/driver-location").toOption.get)
    .addHeader(Header.Authorization.Bearer(token))

  private def tokenFor(role: PersonRole, userId: PersonId): ZIO[Any, Throwable, String] = TestJwt
    .generateToken(role, companyAId, userId)
    .provideLayer(TestJwt.serviceLayer)

  def spec =
    suite("DriverApi — GET /api/rides/{rideId}/driver-location access guard [real serverEndpoints]")(
      test("a same-company CLIENT who is not the ride's client → 403, no coordinates leaked") {
        for {
          repo  <- CheckpointRideRepository.make(assignedRide())
          layers = buildLayers(repo)
          token <- tokenFor(PersonRole.Client, strangerId)
          resp  <- run(proximityReq(token), layers)
          body  <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Forbidden,
          !body.contains("48.2")
        )
      },
      test("a same-company DRIVER who is not assigned to the ride → 403") {
        for {
          repo  <- CheckpointRideRepository.make(assignedRide())
          layers = buildLayers(repo)
          token <- tokenFor(PersonRole.Driver, otherDriverId)
          resp  <- run(proximityReq(token), layers)
        } yield assertTrue(resp.status == Status.Forbidden)
      },
      test("the ride's client can read the driver proximity → 200 with coordinates") {
        for {
          repo  <- CheckpointRideRepository.make(assignedRide())
          layers = buildLayers(repo)
          token <- tokenFor(PersonRole.Client, clientId)
          resp  <- run(proximityReq(token), layers)
          body  <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("48.2")
        )
      },
      test("the assigned driver can read the proximity → 200") {
        for {
          repo  <- CheckpointRideRepository.make(assignedRide())
          layers = buildLayers(repo)
          token <- tokenFor(PersonRole.Driver, driverId)
          resp  <- run(proximityReq(token), layers)
        } yield assertTrue(resp.status == Status.Ok)
      },
      test("a DISPATCHER (staff, not a party) can read the proximity → 200") {
        for {
          repo  <- CheckpointRideRepository.make(assignedRide())
          layers = buildLayers(repo)
          token <- tokenFor(PersonRole.Dispatcher, strangerId)
          resp  <- run(proximityReq(token), layers)
        } yield assertTrue(resp.status == Status.Ok)
      }
    ) @@ TestAspect.sequential
