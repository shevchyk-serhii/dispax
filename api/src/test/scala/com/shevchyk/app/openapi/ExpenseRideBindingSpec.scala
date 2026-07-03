package com.shevchyk.app.openapi

import java.time.Instant
import java.util.UUID

import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.openapi.ExpenseApi
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryExpenseRepository, RideRepository}

/**
 * Endpoint-level tests for POST /api/expenses on ExpenseApi.
 *
 * Regression coverage for the audit finding: `rideId` was taken from the request and persisted without validating that
 * the ride exists in the caller's company (the FK is a bare `REFERENCES rides(id)`), so a driver could attach an
 * expense to another company's ride or to a colleague's ride. The endpoint must reject a cross-company rideId with 404
 * (no existence leak) and, for drivers, a ride they are not assigned to with 403. Staff (DISPATCHER/ADMIN) may
 * reference any ride of their company.
 *
 * Runs the REAL `ExpenseApi.serverEndpoints` through `ZioHttpInterpreter` with a seeded ride repo and an in-memory
 * expense store.
 */
object ExpenseRideBindingSpec extends ZIOSpecDefault:

  // -- Fixtures ------------------------------------------------------------
  private val companyAId    = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val companyBId    = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))
  private val clientId      = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))
  private val driverId      = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val otherDriverId = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000002"))
  private val rideId        = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001"))

  private def seededRide(companyId: CompanyId = companyAId, assignedTo: PersonId = driverId): Ride = Ride(
    id = rideId,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    driverId = Some(assignedTo),
    status = RideStatus.Assigned,
    pickupLocation = Location("Munich Airport"),
    dropoffLocation = Location("Munich City"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    requestTime = Instant.now()
  )

  private def buildLayers(
      repo: CheckpointRideRepository,
      expenses: ExpenseRepository
  ): ZLayer[Any, Throwable, ExpenseApi.ExpenseEnv] =
    TestJwt.serviceLayer ++ ZLayer.succeed(expenses) ++ ZLayer.succeed(repo: RideRepository)

  private def run(req: Request, layers: ZLayer[Any, Throwable, ExpenseApi.ExpenseEnv]): ZIO[Any, Throwable, Response] =
    ZioHttpInterpreter()
      .toHttp(ExpenseApi.serverEndpoints)
      .run(req)
      .either
      .map {
        case Left(r)  => r.merge
        case Right(r) => r
      }
      .provideLayer(layers)

  private def createReq(token: String, rideId: Option[RideId]): Request =
    val rideField = rideId.map(id => s""""rideId":"${id.value}",""").getOrElse("")
    Request
      .post(
        URL.decode("/api/expenses").toOption.get,
        Body.fromString(s"""{${rideField}"category":"Fuel","amount":12.5,"description":"diesel"}""")
      )
      .addHeader(Header.Authorization.Bearer(token))
      .addHeader(Header.ContentType(zio.http.MediaType.application.json))

  private def tokenFor(role: PersonRole, userId: PersonId): ZIO[Any, Throwable, String] = TestJwt
    .generateToken(role, companyAId, userId)
    .provideLayer(TestJwt.serviceLayer)

  def spec =
    suite("ExpenseApi — POST /api/expenses rideId binding [real serverEndpoints]")(
      test("a driver attaching an expense to another company's ride → 404 and nothing persisted") {
        for {
          repo    <- CheckpointRideRepository.make(seededRide(companyId = companyBId))
          expenses = new InMemoryExpenseRepository
          layers   = buildLayers(repo, expenses)
          token   <- tokenFor(PersonRole.Driver, driverId)
          resp    <- run(createReq(token, Some(rideId)), layers)
          stored  <- expenses.findByRideId(rideId)
        } yield assertTrue(
          resp.status == Status.NotFound,
          stored.isEmpty
        )
      },
      test("a driver attaching an expense to a ride they are not assigned to → 403 and nothing persisted") {
        for {
          repo    <- CheckpointRideRepository.make(seededRide(assignedTo = otherDriverId))
          expenses = new InMemoryExpenseRepository
          layers   = buildLayers(repo, expenses)
          token   <- tokenFor(PersonRole.Driver, driverId)
          resp    <- run(createReq(token, Some(rideId)), layers)
          stored  <- expenses.findByRideId(rideId)
        } yield assertTrue(
          resp.status == Status.Forbidden,
          stored.isEmpty
        )
      },
      test("a driver attaching an expense to a nonexistent rideId → 404") {
        for {
          repo    <- CheckpointRideRepository.make(seededRide())
          expenses = new InMemoryExpenseRepository
          layers   = buildLayers(repo, expenses)
          token   <- tokenFor(PersonRole.Driver, driverId)
          resp    <- run(createReq(token, Some(RideId(UUID.randomUUID()))), layers)
        } yield assertTrue(resp.status == Status.NotFound)
      },
      test("a driver attaching an expense to their own assigned company ride → 201 and persisted") {
        for {
          repo    <- CheckpointRideRepository.make(seededRide())
          expenses = new InMemoryExpenseRepository
          layers   = buildLayers(repo, expenses)
          token   <- tokenFor(PersonRole.Driver, driverId)
          resp    <- run(createReq(token, Some(rideId)), layers)
          stored  <- expenses.findByRideId(rideId)
        } yield assertTrue(
          resp.status == Status.Created,
          stored.length == 1,
          stored.head.driverId == driverId,
          stored.head.companyId == companyAId
        )
      },
      test("a dispatcher may attach an expense to any ride of their company → 201") {
        for {
          repo    <- CheckpointRideRepository.make(seededRide(assignedTo = otherDriverId))
          expenses = new InMemoryExpenseRepository
          layers   = buildLayers(repo, expenses)
          token   <- tokenFor(PersonRole.Dispatcher, driverId)
          resp    <- run(createReq(token, Some(rideId)), layers)
        } yield assertTrue(resp.status == Status.Created)
      },
      test("an expense without a rideId is still accepted → 201 (unchanged behaviour)") {
        for {
          repo    <- CheckpointRideRepository.make(seededRide())
          expenses = new InMemoryExpenseRepository
          layers   = buildLayers(repo, expenses)
          token   <- tokenFor(PersonRole.Driver, driverId)
          resp    <- run(createReq(token, None), layers)
          stored  <- expenses.findByDriverId(driverId)
        } yield assertTrue(
          resp.status == Status.Created,
          stored.length == 1,
          stored.head.rideId.isEmpty
        )
      }
    ) @@ TestAspect.sequential
