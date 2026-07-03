package com.shevchyk.app.openapi

import java.time.Instant
import java.util.UUID

import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import zio.*
import zio.http.*
import zio.test.*

import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{GdprRepository, InMemoryPersonRepository}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.openapi.ExpenseApi
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryExpenseRepository, RideRepository}

/**
 * Defense-in-depth company scoping of the self-data reads (audit item): GET /api/gdpr/export and GET /api/expenses used
 * to read by the caller's id alone (`findByClientId/findByDriverId(user.userId)`) with no company filter. One PersonId
 * belongs to one company today, so this was not exploitable — but a future id collision (or a person moved across
 * companies) would silently leak another company's rows. Both endpoints must use the `*AndCompany` variants, scoped by
 * the JWT company.
 *
 * Runs the REAL `GdprApi.serverEndpoints` / `ExpenseApi.serverEndpoints` through `ZioHttpInterpreter`, seeding rows
 * with the SAME person id under two different companies and asserting the foreign-company rows never surface.
 */
object SelfDataCompanyScopeSpec extends ZIOSpecDefault:

  // -- Fixtures ------------------------------------------------------------
  private val companyAId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  private val companyBId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))
  private val userId     = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))

  private val rideInA = RideId(UUID.fromString("000000AA-AAAA-0000-0000-00000000000A"))
  private val rideInB = RideId(UUID.fromString("000000AA-AAAA-0000-0000-00000000000B"))

  private def ride(id: RideId, companyId: CompanyId): Ride = Ride(
    id = id,
    clientId = userId,
    creatorId = userId,
    companyId = companyId,
    driverId = Some(userId),
    status = RideStatus.Completed,
    pickupLocation = Location(s"From-${id.value}"),
    dropoffLocation = Location(s"To-${id.value}"),
    pickupDateTime = Instant.now().minusSeconds(7200),
    requestTime = Instant.now().minusSeconds(9000)
  )

  private def expense(companyId: CompanyId, description: String): Expense = Expense(
    id = ExpenseId.generate(),
    driverId = userId,
    companyId = companyId,
    category = ExpenseCategory.Fuel,
    amount = BigDecimal(10),
    description = Some(description)
  )

  private def seededExpenses: ZIO[Any, Throwable, ExpenseRepository] =
    val repo = new InMemoryExpenseRepository
    repo.create(expense(companyAId, "own-company-expense")) *>
      repo.create(expense(companyBId, "foreign-company-expense")).as(repo)

  private def driverToken: ZIO[Any, Throwable, String] = TestJwt
    .generateToken(PersonRole.Driver, companyAId, userId)
    .provideLayer(TestJwt.serviceLayer)

  private def get(path: String, token: String): Request = Request
    .get(URL.decode(path).toOption.get)
    .addHeader(Header.Authorization.Bearer(token))

  // -- GDPR export ----------------------------------------------------------

  private def runGdpr(req: Request, rides: RideRepository, expenses: ExpenseRepository) = ZioHttpInterpreter()
    .toHttp(GdprApi.serverEndpoints)
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }
    .provideLayer(
      TestJwt.serviceLayer ++ GdprRepository.inMemory ++ InMemoryPersonRepository.layer ++
        ZLayer.succeed(rides) ++ ZLayer.succeed(expenses)
    )

  // -- Expense list ----------------------------------------------------------

  private def runExpenses(req: Request, expenses: ExpenseRepository) = ZioHttpInterpreter()
    .toHttp(ExpenseApi.serverEndpoints)
    .run(req)
    .either
    .map {
      case Left(r)  => r.merge
      case Right(r) => r
    }
    .provideLayer(
      TestJwt.serviceLayer ++ ZLayer.succeed(expenses) ++
        ZLayer.fromZIO(CheckpointRideRepository.make().map(r => r: RideRepository))
    )

  def spec =
    suite("Self-data reads are company-scoped (defense-in-depth)")(
      test("GET /api/gdpr/export only exports rides and expenses of the caller's own company") {
        for {
          rideRepo <- CheckpointRideRepository.make(ride(rideInA, companyAId), ride(rideInB, companyBId))
          expenses <- seededExpenses
          token    <- driverToken
          resp     <- runGdpr(get("/api/gdpr/export", token), rideRepo, expenses)
          body     <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains(rideInA.value.toString),
          !body.contains(rideInB.value.toString),
          body.contains("own-company-expense"),
          !body.contains("foreign-company-expense")
        )
      },
      test("GET /api/expenses as a driver only lists the caller's own-company expenses") {
        for {
          expenses <- seededExpenses
          token    <- driverToken
          resp     <- runExpenses(get("/api/expenses", token), expenses)
          body     <- resp.body.asString
        } yield assertTrue(
          resp.status == Status.Ok,
          body.contains("own-company-expense"),
          !body.contains("foreign-company-expense")
        )
      }
    ) @@ TestAspect.sequential
