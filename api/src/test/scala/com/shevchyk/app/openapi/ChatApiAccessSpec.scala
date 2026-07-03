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
import com.shevchyk.ride.repository.{
  ChatMessageRepository,
  InMemoryChatMessageRepository,
  InMemoryTariffRepository,
  RideRatingRepository,
  RideRepository,
  TariffRepository
}

/**
 * Endpoint-level tests for the ride chat routes on RideApi:
 *   - POST /api/rides/{id}/chat (send; CLIENT/DRIVER)
 *   - GET /api/rides/{id}/chat (read; CLIENT/DRIVER/DISPATCHER)
 *
 * Runs the REAL `RideApi.serverEndpoints` through `ZioHttpInterpreter` over the REAL `ChatService` (typed `ChatError`
 * channel, message validation) backed by an in-memory chat store, with `getRideById` reading the seeded ride.
 *
 * Regression coverage for the audit findings:
 *   - participation: a same-company CLIENT/DRIVER who is NOT a party of the ride must not read or write its chat (403);
 *   - message validation: empty/whitespace-only messages and messages above the length cap are rejected (400);
 *   - typed errors: chat on a non-active ride maps to 400 (was an untyped RuntimeException collapsing to 500).
 */
object ChatApiAccessSpec extends ZIOSpecDefault:

  // -- Fixtures ------------------------------------------------------------
  private val companyAId    = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val clientId      = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val strangerId    = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000002"))
  private val driverId      = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val otherDriverId = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000002"))
  private val rideId        = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))

  private def assignedRide(status: RideStatus = RideStatus.Assigned): Ride = Ride(
    id = rideId,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyAId,
    driverId = Some(driverId),
    status = status,
    pickupLocation = Location("Munich Airport"),
    dropoffLocation = Location("Munich City"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    requestTime = Instant.now()
  )

  // -- Stub layers for the parts of RideEnv the chat routes never touch ----
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

  private val stubTariffRepo: ZLayer[Any, Nothing, TariffRepository] = ZLayer.succeed(new InMemoryTariffRepository())

  private val stubRideEstimateService: ZLayer[Any, Nothing, RideEstimateService] =
    stubTariffRepo >>> RideEstimateService.live

  private def buildLayers(
      repo: CheckpointRideRepository,
      chatRepo: ChatMessageRepository = new InMemoryChatMessageRepository
  ): ZLayer[Any, Throwable, RideApi.RideEnv] =
    val repoLayer          = ZLayer.succeed(repo: RideRepository)
    // A FRESH chat store per test (the shared singleton would leak across tests). Passed in so a
    // send-then-read test shares ONE store instance across its two separate `run` (.provideLayer)
    // calls — otherwise the reader gets a fresh empty store and never sees the sent message.
    val chatSvcLayer       =
      (ZLayer.succeed(chatRepo) ++ repoLayer ++ EventHub.layer) >>>
        ChatService.layer
    val checkpointSvcLayer =
      (repoLayer ++ EventHub.layer ++ StubAirportConfigService.layer) >>>
        AirportCheckpointService.layer
    TestJwt.serviceLayer ++
      RideServiceFromRepo.layer(repo) ++
      stubClientAddressService ++
      stubClientLocationService ++
      checkpointSvcLayer ++
      chatSvcLayer ++
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

  private def sendReq(token: String, message: String): Request = Request
    .post(
      URL.decode(s"/api/rides/${rideId.value}/chat").toOption.get,
      Body.fromString(s"""{"message":${zio.json.JsonEncoder.string.encodeJson(message, None)}}""")
    )
    .addHeader(Header.Authorization.Bearer(token))
    .addHeader(Header.ContentType(zio.http.MediaType.application.json))

  private def getReq(token: String): Request = Request
    .get(URL.decode(s"/api/rides/${rideId.value}/chat").toOption.get)
    .addHeader(Header.Authorization.Bearer(token))

  private def tokenFor(role: PersonRole, userId: PersonId): ZIO[Any, Throwable, String] = TestJwt
    .generateToken(role, companyAId, userId)
    .provideLayer(TestJwt.serviceLayer)

  def spec =
    suite("RideApi — ride chat endpoints [real serverEndpoints]")(
      suite("participation guard")(
        test("a same-company CLIENT who is not the ride's client cannot send → 403 and nothing is stored") {
          for {
            repo  <- CheckpointRideRepository.make(assignedRide())
            layers = buildLayers(repo)
            token <- tokenFor(PersonRole.Client, strangerId)
            resp  <- run(sendReq(token, "hi from a stranger"), layers)
            owner <- tokenFor(PersonRole.Client, clientId)
            get   <- run(getReq(owner), layers)
            body  <- get.body.asString
          } yield assertTrue(
            resp.status == Status.Forbidden,
            !body.contains("stranger")
          )
        },
        test("a same-company CLIENT who is not the ride's client cannot read → 403") {
          for {
            repo  <- CheckpointRideRepository.make(assignedRide())
            layers = buildLayers(repo)
            token <- tokenFor(PersonRole.Client, strangerId)
            resp  <- run(getReq(token), layers)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("a same-company DRIVER who is not assigned to the ride cannot read → 403") {
          for {
            repo  <- CheckpointRideRepository.make(assignedRide())
            layers = buildLayers(repo)
            token <- tokenFor(PersonRole.Driver, otherDriverId)
            resp  <- run(getReq(token), layers)
          } yield assertTrue(resp.status == Status.Forbidden)
        },
        test("the ride's client can send → 201, and the assigned driver reads it → 200") {
          for {
            repo   <- CheckpointRideRepository.make(assignedRide())
            layers  = buildLayers(repo, new InMemoryChatMessageRepository)
            client <- tokenFor(PersonRole.Client, clientId)
            sent   <- run(sendReq(client, "see you at the gate"), layers)
            driver <- tokenFor(PersonRole.Driver, driverId)
            get    <- run(getReq(driver), layers)
            body   <- get.body.asString
          } yield assertTrue(
            sent.status == Status.Created,
            get.status == Status.Ok,
            body.contains("see you at the gate")
          )
        },
        test("a DISPATCHER (staff, not a party) can still read → 200") {
          for {
            repo  <- CheckpointRideRepository.make(assignedRide())
            layers = buildLayers(repo)
            token <- tokenFor(PersonRole.Dispatcher, strangerId)
            resp  <- run(getReq(token), layers)
          } yield assertTrue(resp.status == Status.Ok)
        }
      ),
      suite("message validation")(
        test("an empty message → 400 and nothing is stored") {
          for {
            repo   <- CheckpointRideRepository.make(assignedRide())
            layers  = buildLayers(repo)
            client <- tokenFor(PersonRole.Client, clientId)
            resp   <- run(sendReq(client, ""), layers)
            get    <- run(getReq(client), layers)
            body   <- get.body.asString
          } yield assertTrue(
            resp.status == Status.BadRequest,
            body == "[]"
          )
        },
        test("a whitespace-only message → 400") {
          for {
            repo   <- CheckpointRideRepository.make(assignedRide())
            layers  = buildLayers(repo)
            client <- tokenFor(PersonRole.Client, clientId)
            resp   <- run(sendReq(client, "   \t "), layers)
          } yield assertTrue(resp.status == Status.BadRequest)
        },
        test("a message above the 2000-character cap → 400") {
          for {
            repo   <- CheckpointRideRepository.make(assignedRide())
            layers  = buildLayers(repo)
            client <- tokenFor(PersonRole.Client, clientId)
            resp   <- run(sendReq(client, "x" * 2001), layers)
          } yield assertTrue(resp.status == Status.BadRequest)
        },
        test("a message exactly at the 2000-character cap is accepted → 201") {
          for {
            repo   <- CheckpointRideRepository.make(assignedRide())
            layers  = buildLayers(repo)
            client <- tokenFor(PersonRole.Client, clientId)
            resp   <- run(sendReq(client, "x" * 2000), layers)
          } yield assertTrue(resp.status == Status.Created)
        }
      ),
      suite("typed errors")(
        test("sending on a Completed ride → 400 (was an untyped 500)") {
          for {
            repo   <- CheckpointRideRepository.make(assignedRide(status = RideStatus.Completed))
            layers  = buildLayers(repo)
            client <- tokenFor(PersonRole.Client, clientId)
            resp   <- run(sendReq(client, "too late"), layers)
          } yield assertTrue(resp.status == Status.BadRequest)
        }
      )
    ) @@ TestAspect.sequential
