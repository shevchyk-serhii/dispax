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
import com.shevchyk.driver.application.{DriverLocationService, EtaService, HereRoutingService}
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.driver.openapi.DriverApi
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.ClientLocationRepository

/**
 * Endpoint-level tests for the ETA on GET /api/rides/{rideId}/driver-location.
 *
 * Regression coverage for two audit findings:
 *   - the handler duplicated `EtaService`'s Haversine formula instead of delegating (SOLID/DRY) — the endpoint must
 *     return exactly what `EtaService.etaForRide` computes;
 *   - the old inline assembly fell back to `getOrElse(0.0)` per coordinate, so a ride whose pickup had exactly one
 *     coordinate produced an ETA towards a fake 0.0 coordinate ("Null Island") instead of skipping the ETA.
 *
 * Runs the REAL `DriverApi.serverEndpoints` through `ZioHttpInterpreter`.
 */
object DriverEtaDelegationSpec extends ZIOSpecDefault:

  private val companyAId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val clientId   = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val driverId   = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val rideId     = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))

  private def rideWith(pickup: Location): Ride = Ride(
    id = rideId,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyAId,
    driverId = Some(driverId),
    status = RideStatus.Assigned,
    pickupLocation = pickup,
    dropoffLocation = Location("Munich City"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    requestTime = Instant.now()
  )

  // -- Stub layers -----------------------------------------------------------
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
      def updateLastLogin(id: PersonId, companyId: Option[CompanyId]): Task[Unit]                            = ZIO.unit
      def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]                          = ZIO.succeed(Nil)
      def upsertDriverRow(personId: PersonId): Task[Unit]                                                    = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                       = ZIO.none
      def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] = ZIO.unit
      def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                                       = ZIO.unit
  )

  // The real EtaService implementation over the stubs (HERE answers 7 minutes).
  private val realEtaService: ZLayer[Any, Nothing, EtaService] =
    (stubLocationService ++ stubHereRouting ++ GeocodingService.noop ++ stubClientLocationRepo) >>> EtaService.layer

  // A sentinel EtaService: whatever it computes must be what the endpoint returns.
  private val sentinelEtaService: ZLayer[Any, Nothing, EtaService] = ZLayer.succeed(
    new EtaService:
      def etaForRide(ride: Ride): Task[Option[Int]] = ZIO.some(42)
  )

  private def buildLayers(
      repo: CheckpointRideRepository,
      eta: ZLayer[Any, Nothing, EtaService]
  ): ZLayer[Any, Throwable, DriverApi.DriverEnv] =
    TestJwt.serviceLayer ++
      RideServiceFromRepo.layer(repo) ++
      stubLocationService ++
      eta ++
      GeocodingService.noop ++
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

  private def dispatcherToken: ZIO[Any, Throwable, String] = TestJwt
    .generateToken(PersonRole.Dispatcher, companyAId, PersonId(UUID.randomUUID()))
    .provideLayer(TestJwt.serviceLayer)

  def spec =
    suite("DriverApi — ETA delegation to EtaService [real serverEndpoints]")(
      test("the endpoint returns exactly the ETA computed by EtaService (delegation, no local copy)") {
        for {
          repo  <- CheckpointRideRepository.make(rideWith(Location("Munich Airport", Some(48.3538), Some(11.7861))))
          token <- dispatcherToken
          resp  <- run(proximityReq(token), buildLayers(repo, sentinelEtaService))
          body  <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("\"etaMinutes\":42")
        )
      },
      test("pickup with exactly one coordinate → no ETA (never computed against a fake 0.0 coordinate)") {
        // Longitude is missing: the old inline fallback substituted 0.0 and passed
        // the `!= 0.0` guard via the real latitude, producing an ETA to (48.35, 0.0).
        for {
          repo  <- CheckpointRideRepository.make(rideWith(Location("Munich Airport", Some(48.3538), None)))
          token <- dispatcherToken
          resp  <- run(proximityReq(token), buildLayers(repo, realEtaService))
          body  <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          !body.contains("etaMinutes")
        )
      },
      test("pickup with both coordinates still yields an ETA through the real EtaService") {
        for {
          repo  <- CheckpointRideRepository.make(rideWith(Location("Munich Airport", Some(48.3538), Some(11.7861))))
          token <- dispatcherToken
          resp  <- run(proximityReq(token), buildLayers(repo, realEtaService))
          body  <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("\"etaMinutes\":7")
        )
      }
    ) @@ TestAspect.sequential
