package com.shevchyk.app.openapi

import java.time.Instant
import java.util.UUID

import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import com.shevchyk.core.application.{EventHub, GeocodingService}
import com.shevchyk.core.config.AirportArrivalTimingConfig
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.application.service.{
  AirportCheckpointService,
  AirportTimingService,
  ChatService,
  ClientAddressService,
  ClientLocationService,
  RideEstimateService,
  RideService
}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.openapi.RideApi
import com.shevchyk.ride.repository.{InMemoryTariffRepository, RideRatingRepository, RideRepository, TariffRepository}

/**
 * Endpoint-level tests for the airport-checkpoint routes on RideApi, previously untested:
 *   - POST /api/rides/{id}/airport-checkpoint (mark; CLIENT only)
 *   - GET /api/rides/{id}/airport-checkpoint (read state)
 *
 * Runs the REAL `RideApi.serverEndpoints` through `ZioHttpInterpreter` over the REAL `AirportCheckpointService` (its
 * forward-only guard and status pre-checks), with `getRideById` reading from the same stateful repo so a marked
 * checkpoint is visible to the subsequent GET.
 *
 * Covered: CLIENT marks a checkpoint → 204 and GET reflects it; a non-CLIENT role marking → 403; cross-tenant ride →
 * 404 (no existence leak); an invalid checkpoint value → 400; GET on a ride with no checkpoint → null state.
 */
object RideCheckpointApiSpec extends ZIOSpecDefault:

  // -- Fixtures ------------------------------------------------------------
  private val companyAId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val companyBId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))
  private val clientId   = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val driverId   = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val rideId     = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))

  private def arrivalRide(
      companyId: CompanyId = companyAId,
      checkpoint: Option[AirportCheckpoint] = None
  ): Ride = Ride(
    id = rideId,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    driverId = Some(driverId),
    status = RideStatus.Assigned,
    pickupLocation = Location("MUC Airport"),
    dropoffLocation = Location("Munich City"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    requestTime = Instant.now(),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", Some("LH123"), isArrival = true)),
    airportCheckpoint = checkpoint
  )

  // -- Stub layers for the parts of RideEnv the checkpoint routes never touch
  private val stubClientAddressService: ZLayer[Any, Nothing, ClientAddressService] = ZLayer.succeed(
    new ClientAddressService:
      def getAddresses(clientId: PersonId)                                                                          = ZIO.succeed(Nil)
      def saveAddress(clientId: PersonId, req: SaveClientAddressRequest)                                            = ZIO.die(new NotImplementedError("stub"))
      def updateAddress(id: ClientAddressId, clientId: PersonId, req: UpdateClientAddressRequest)                   = ZIO.none
      def recordUsage(clientId: PersonId, address: String, label: String, lat: Option[Double], lng: Option[Double]) =
        ZIO.unit
      def deleteAddress(id: ClientAddressId, clientId: PersonId)                                                    = ZIO.succeed(false)
  )

  private val stubClientLocationService: ZLayer[Any, Nothing, ClientLocationService] = ZLayer.succeed(
    new ClientLocationService:
      def updateClientLocation(rideId: RideId, clientId: PersonId, latitude: Double, longitude: Double) = ZIO.die(
        new NotImplementedError("stub")
      )
      def getRideLocations(rideId: RideId)                                                              = ZIO.die(new NotImplementedError("stub"))
  )

  private val stubChatService: ZLayer[Any, Nothing, ChatService] = ZLayer.succeed(
    new ChatService:
      def sendMessage(rideId: RideId, senderId: PersonId, message: String) = ZIO.die(new NotImplementedError("stub"))
      def getMessages(rideId: RideId)                                      = ZIO.succeed(Nil)
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

  private val stubTariffRepo: ZLayer[Any, Nothing, TariffRepository]             = ZLayer.succeed(new InMemoryTariffRepository())

  private val stubRideEstimateService: ZLayer[Any, Nothing, RideEstimateService] =
    stubTariffRepo >>> RideEstimateService.live

  private def buildLayers(repo: CheckpointRideRepository): ZLayer[Any, Throwable, RideApi.RideEnv] =
    val repoLayer          = ZLayer.succeed(repo: RideRepository)
    val checkpointSvcLayer =
      (repoLayer ++ EventHub.layer ++ StubAirportConfigService.layer) >>>
        AirportCheckpointService.layer
    TestJwt.serviceLayer ++
      RideServiceFromRepo.layer(repo) ++
      stubClientAddressService ++
      stubClientLocationService ++
      checkpointSvcLayer ++
      stubChatService ++
      RideRatingRepository.inMemory ++
      stubPersonRepo ++
      stubTariffRepo ++
      stubRideEstimateService ++
      GeocodingService.noop ++
      AirportTimingService.noopLayer ++
      AirportArrivalTimingConfig.liveLayer ++
      EventHub.layer ++
      StubFlightStatusProvider.layer ++
      repoLayer

  private def run(req: Request, layers: ZLayer[Any, Throwable, RideApi.RideEnv]): ZIO[Any, Throwable, Response] =
    ZioHttpInterpreter()
      .toHttp(RideApi.serverEndpoints)
      .run(req)
      .either
      .map {
        case Left(r)  => r.merge
        case Right(r) => r
      }
      .provideLayer(layers)

  private def markReq(token: String, checkpoint: String): Request = Request
    .post(
      URL.decode(s"/api/rides/${rideId.value}/airport-checkpoint").toOption.get,
      Body.fromString(s"""{"checkpoint":"$checkpoint"}""")
    )
    .addHeader(Header.Authorization.Bearer(token))
    .addHeader(Header.ContentType(zio.http.MediaType.application.json))

  private def getReq(token: String): Request = Request
    .get(URL.decode(s"/api/rides/${rideId.value}/airport-checkpoint").toOption.get)
    .addHeader(Header.Authorization.Bearer(token))

  def spec =
    suite("RideApi — airport-checkpoint mark/get endpoints [real serverEndpoints]")(
      test("CLIENT marks a checkpoint → 204, and GET reflects the new state") {
        for {
          repo  <- CheckpointRideRepository.make(arrivalRide())
          layers = buildLayers(repo)
          token <- TestJwt.generateToken(PersonRole.Client, companyAId).provideLayer(TestJwt.serviceLayer)
          mark  <- run(markReq(token, "landed"), layers)
          get   <- run(getReq(token), layers)
          body  <- get.body.asString
        } yield assertTrue(
          mark.status == Status.NoContent,
          get.status == Status.Ok,
          body.contains("\"checkpoint\":\"landed\"")
        )
      },
      test("a non-CLIENT role (DISPATCHER) marking a checkpoint → 403") {
        for {
          repo  <- CheckpointRideRepository.make(arrivalRide())
          layers = buildLayers(repo)
          token <- TestJwt.generateToken(PersonRole.Dispatcher, companyAId).provideLayer(TestJwt.serviceLayer)
          resp  <- run(markReq(token, "landed"), layers)
          saved <- repo.findById(rideId)
        } yield assertTrue(
          resp.status == Status.Forbidden,
          saved.flatMap(_.airportCheckpoint).isEmpty
        )
      },
      test("CLIENT of company A marking a ride owned by company B → 404 (no existence leak)") {
        for {
          repo  <- CheckpointRideRepository.make(arrivalRide(companyId = companyBId))
          layers = buildLayers(repo)
          // Token is for company A; the ride belongs to company B.
          token <- TestJwt.generateToken(PersonRole.Client, companyAId).provideLayer(TestJwt.serviceLayer)
          resp  <- run(markReq(token, "landed"), layers)
          saved <- repo.findById(rideId)
        } yield assertTrue(
          resp.status == Status.NotFound,
          saved.flatMap(_.airportCheckpoint).isEmpty
        )
      },
      test("an invalid checkpoint value → 400") {
        for {
          repo  <- CheckpointRideRepository.make(arrivalRide())
          layers = buildLayers(repo)
          token <- TestJwt.generateToken(PersonRole.Client, companyAId).provideLayer(TestJwt.serviceLayer)
          resp  <- run(markReq(token, "not_a_checkpoint"), layers)
          saved <- repo.findById(rideId)
        } yield assertTrue(
          resp.status == Status.BadRequest,
          saved.flatMap(_.airportCheckpoint).isEmpty
        )
      },
      test("GET on a ride with no checkpoint reports an empty checkpoint state") {
        for {
          repo  <- CheckpointRideRepository.make(arrivalRide())
          layers = buildLayers(repo)
          token <- TestJwt.generateToken(PersonRole.Client, companyAId).provideLayer(TestJwt.serviceLayer)
          get   <- run(getReq(token), layers)
          body  <- get.body.asString
        } yield assertTrue(
          get.status == Status.Ok,
          // zio-json omits None fields, so an unset checkpoint serialises to no checkpoint value at all.
          !body.contains("\"checkpoint\":\""),
          !body.contains("landed")
        )
      }
    ) @@ TestAspect.sequential
