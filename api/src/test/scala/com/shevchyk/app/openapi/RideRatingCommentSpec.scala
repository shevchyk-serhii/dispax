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
  RideEstimateService
}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.openapi.RideApi
import com.shevchyk.ride.repository.{InMemoryTariffRepository, RideRatingRepository, RideRepository, TariffRepository}

/**
 * Endpoint-level tests for POST /api/rides/{rideId}/rate on RideApi.
 *
 * Regression coverage for the audit finding: `RideRating.comment` had no length cap — arbitrary public input flowed
 * into the TEXT column unbounded. The endpoint must reject an over-long comment with 400 while a comment at the limit
 * still passes. Runs the REAL `RideApi.serverEndpoints` through `ZioHttpInterpreter`.
 */
object RideRatingCommentSpec extends ZIOSpecDefault:

  // -- Fixtures ------------------------------------------------------------
  private val companyAId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val clientId   = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val driverId   = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val rideId     = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))

  private def completedRide: Ride = Ride(
    id = rideId,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyAId,
    driverId = Some(driverId),
    status = RideStatus.Completed,
    pickupLocation = Location("Munich Airport"),
    dropoffLocation = Location("Munich City"),
    pickupDateTime = Instant.now().minusSeconds(7200),
    requestTime = Instant.now().minusSeconds(9000)
  )

  // -- Stub layers for the parts of RideEnv the rating route never touches --
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
      ratings: RideRatingRepository
  ): ZLayer[Any, Throwable, RideApi.RideEnv] =
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
      ZLayer.succeed(ratings) ++
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

  private def rateReq(token: String, comment: String): Request = Request
    .post(
      URL.decode(s"/api/rides/${rideId.value}/rate").toOption.get,
      Body.fromString(s"""{"rating":5,"comment":"$comment"}""")
    )
    .addHeader(Header.Authorization.Bearer(token))
    .addHeader(Header.ContentType(zio.http.MediaType.application.json))

  private def clientToken: ZIO[Any, Throwable, String] = TestJwt
    .generateToken(PersonRole.Client, companyAId, clientId)
    .provideLayer(TestJwt.serviceLayer)

  def spec =
    suite("RideApi — POST /api/rides/{id}/rate comment length [real serverEndpoints]")(
      test("a comment longer than 1000 characters → 400 and nothing persisted") {
        for {
          repo   <- CheckpointRideRepository.make(completedRide)
          ratings = new com.shevchyk.ride.repository.InMemoryRideRatingRepository
          layers  = buildLayers(repo, ratings)
          token  <- clientToken
          resp   <- run(rateReq(token, "x" * 1001), layers)
          stored <- ratings.findByRideId(rideId)
        } yield assertTrue(
          resp.status == Status.BadRequest,
          stored.isEmpty
        )
      },
      test("a comment of exactly 1000 characters is still accepted → 201") {
        for {
          repo   <- CheckpointRideRepository.make(completedRide)
          ratings = new com.shevchyk.ride.repository.InMemoryRideRatingRepository
          layers  = buildLayers(repo, ratings)
          token  <- clientToken
          resp   <- run(rateReq(token, "x" * 1000), layers)
          stored <- ratings.findByRideId(rideId)
        } yield assertTrue(
          resp.status == Status.Created,
          stored.exists(_.comment.exists(_.length == 1000))
        )
      }
    ) @@ TestAspect.sequential
