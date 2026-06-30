package com.shevchyk.app.openapi

import java.time.Instant
import java.util.UUID

import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.config.PublicLinkConfig
import com.shevchyk.core.domain.*
import com.shevchyk.driver.application.{DriverLocationService, EtaService}
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.ride.application.service.{
  AirportCheckpointService,
  ResolvedShare,
  RideService,
  RideShareTokenService
}
import com.shevchyk.ride.domain.*

/**
 * End-to-end tests for the PUBLIC guest checkpoint endpoint `POST /api/track/{token}/checkpoint`.
 *
 * These run the REAL `TrackApi.serverEndpoints` through `ZioHttpInterpreter` over the REAL `AirportCheckpointService`
 * (its forward-only guard, status pre-checks, and idempotency are exercised for real). The pre-existing `TrackApiSpec`
 * only re-implemented the handler with `(_,_) => ZIO.unit`, so it never touched the actual endpoint logic — this spec
 * closes that gap.
 *
 * Covered:
 *   1. valid token + fresh checkpoint → 204, and the ride's checkpoint is persisted 2. monotonic progression (Landed →
 *      ArrivalsHall) → 204 each, state advances 3. double-tap / non-advancing checkpoint → 204 (InvalidOperation
 *      swallowed, idempotent), state unchanged 4. unknown checkpoint value → 404 (generic, no existence leak) 5.
 *      unknown / unresolvable token → 404
 */
object TrackApiCheckpointSpec extends ZIOSpecDefault:

  // -- Fixtures ------------------------------------------------------------
  private val companyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val clientId  = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val driverId  = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val rideId    = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))

  private val validToken = "valid-guest-token"

  private def arrivalRide(checkpoint: Option[AirportCheckpoint] = None): Ride = Ride(
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

  // RideShareTokenService double: resolves only `validToken` to our ride; anything else is ShareTokenInvalid.
  private val stubShareTokenService: ZLayer[Any, Nothing, RideShareTokenService] = ZLayer.succeed(
    new RideShareTokenService:
      def generateForRide(rideId: RideId, companyId: CompanyId): IO[RideError, String] = ZIO.die(
        new NotImplementedError("stub")
      )
      def resolve(token: String): IO[RideError, ResolvedShare]                         =
        if token == validToken then ZIO.succeed(ResolvedShare(rideId, companyId))
        else ZIO.fail(RideError.ShareTokenInvalid)
  )

  // Unused by the checkpoint path, but required to satisfy TrackEnv — safe defaults.
  private val stubDriverLocationService: ZLayer[Any, Nothing, DriverLocationService] = ZLayer.succeed(
    new DriverLocationService:
      def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit] = ZIO.unit
      def getLocation(driverId: PersonId): Task[Option[DriverLocation]]                       = ZIO.none
      def updateAvailability(driverId: PersonId, status: String): Task[Unit]                  = ZIO.unit
      def getAvailability(driverId: PersonId): Task[Option[String]]                           = ZIO.none
      def getAvailableDrivers(
          companyId: CompanyId
      ): Task[List[com.shevchyk.driver.infrastructure.http.AvailableDriverDto]] = ZIO.succeed(Nil)
  )

  private val stubEtaService: ZLayer[Any, Nothing, EtaService] = ZLayer.succeed(
    new EtaService:
      def etaForRide(ride: Ride): Task[Option[Int]] = ZIO.none
  )

  // -- Layer builder -------------------------------------------------------
  // Real AirportCheckpointService over the stateful CheckpointRideRepository + EventHub + stub config.
  private def buildLayers(repo: CheckpointRideRepository): ZLayer[Any, Throwable, TrackApi.TrackEnv] =
    val repoLayer          = ZLayer.succeed(repo: com.shevchyk.ride.repository.RideRepository)
    val checkpointSvcLayer =
      (repoLayer ++ EventHub.layer ++ StubAirportConfigService.layer) >>>
        AirportCheckpointService.layer
    TestJwt.serviceLayer ++
      stubShareTokenService ++
      RideServiceFromRepo.layer(repo) ++
      stubDriverLocationService ++
      stubEtaService ++
      PublicLinkConfig.liveLayer ++
      checkpointSvcLayer

  private def run(req: Request, layers: ZLayer[Any, Throwable, TrackApi.TrackEnv]): ZIO[Any, Throwable, Response] =
    ZioHttpInterpreter()
      .toHttp(TrackApi.serverEndpoints)
      .run(req)
      .either
      .map {
        case Left(r)  => r.merge
        case Right(r) => r
      }
      .provideLayer(layers)

  private def checkpointReq(token: String, checkpoint: String): Request = Request
    .post(
      URL.decode(s"/api/track/$token/checkpoint").toOption.get,
      Body.fromString(s"""{"checkpoint":"$checkpoint"}""")
    )
    .addHeader(Header.ContentType(zio.http.MediaType.application.json))

  def spec =
    suite("TrackApi — public guest checkpoint endpoint [real serverEndpoints]")(
      test("valid token + fresh checkpoint → 204 and the ride checkpoint is persisted") {
        for {
          repo  <- CheckpointRideRepository.make(arrivalRide())
          resp  <- run(checkpointReq(validToken, "landed"), buildLayers(repo))
          saved <- repo.findById(rideId)
        } yield assertTrue(
          resp.status == Status.NoContent,
          saved.flatMap(_.airportCheckpoint).contains(AirportCheckpoint.Landed)
        )
      },
      test("monotonic progression Landed → ArrivalsHall advances the stored checkpoint") {
        for {
          repo  <- CheckpointRideRepository.make(arrivalRide())
          r1    <- run(checkpointReq(validToken, "landed"), buildLayers(repo))
          r2    <- run(checkpointReq(validToken, "arrivals_hall"), buildLayers(repo))
          saved <- repo.findById(rideId)
        } yield assertTrue(
          r1.status == Status.NoContent,
          r2.status == Status.NoContent,
          saved.flatMap(_.airportCheckpoint).contains(AirportCheckpoint.ArrivalsHall)
        )
      },
      test("double-tap of the same checkpoint → 204 (idempotent), state unchanged") {
        for {
          repo  <- CheckpointRideRepository.make(arrivalRide(checkpoint = Some(AirportCheckpoint.ArrivalsHall)))
          // Re-tapping an already-passed checkpoint must NOT error; the endpoint swallows InvalidOperation as 204.
          resp  <- run(checkpointReq(validToken, "landed"), buildLayers(repo))
          saved <- repo.findById(rideId)
        } yield assertTrue(
          resp.status == Status.NoContent,
          // The earlier (further) checkpoint is preserved — no backwards move.
          saved.flatMap(_.airportCheckpoint).contains(AirportCheckpoint.ArrivalsHall)
        )
      },
      test("unknown checkpoint value → 404 (no existence leak)") {
        for {
          repo  <- CheckpointRideRepository.make(arrivalRide())
          resp  <- run(checkpointReq(validToken, "not_a_checkpoint"), buildLayers(repo))
          saved <- repo.findById(rideId)
        } yield assertTrue(
          resp.status == Status.NotFound,
          saved.flatMap(_.airportCheckpoint).isEmpty
        )
      },
      test("unknown token → 404") {
        for {
          repo  <- CheckpointRideRepository.make(arrivalRide())
          resp  <- run(checkpointReq("bogus-token", "landed"), buildLayers(repo))
          saved <- repo.findById(rideId)
        } yield assertTrue(
          resp.status == Status.NotFound,
          saved.flatMap(_.airportCheckpoint).isEmpty
        )
      }
    ) @@ TestAspect.sequential
