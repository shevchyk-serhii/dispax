package com.shevchyk.notification.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.notification.repository.PostgresSentConfirmationRequestRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Integration tests for [[PostgresSentConfirmationRequestRepository]] against a real PostgreSQL database via
 * Testcontainers.
 *
 * Covers:
 *   - markSent / isAlreadySent: basic dedup round-trip
 *   - markSent is idempotent (ON CONFLICT DO NOTHING)
 *   - clear removes all records for a ride while leaving other rides unaffected
 *   - isAlreadySent returns false before any markSent
 *   - per-person granularity: different persons on the same ride are independent
 */
object PostgresSentConfirmationRequestRepositorySpec extends ZIOSpecDefault:

  private val company = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000099"))
  private val client  = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000099"))
  private val driver1 = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000D1"))
  private val driver2 = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000D2"))

  private def seedBaseData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${company.value}, 'Test GmbH', 'test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${client.value}, 'Test Client', 'client@test.com',
                         'client'::person_role, ${company.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driver1.value}, 'Driver 1', 'driver1@test.com',
                         'driver'::person_role, ${company.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driver2.value}, 'Driver 2', 'driver2@test.com',
                         'driver'::person_role, ${company.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def insertRide(xa: Transactor[Task]): Task[RideId] =
    val rideId = RideId(UUID.randomUUID())
    sql"""INSERT INTO rides (id, client_id, creator_id, company_id, from_address, to_address, pickup_datetime)
          VALUES (${rideId.value}, ${client.value}, ${client.value}, ${company.value},
                  'Pickup St', 'Dropoff St', ${Instant.now().plusSeconds(3600)})""".update.run
      .transact(xa)
      .as(rideId)

  private def cleanSentConfirmations(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM sent_confirmation_requests".update.run.transact(xa).unit

  def spec =
    suite("PostgresSentConfirmationRequestRepository")(
      test("isAlreadySent returns false before any markSent call") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedBaseData(xa)
          _      <- cleanSentConfirmations(xa)
          rideId <- insertRide(xa)
          repo    = PostgresSentConfirmationRequestRepository(xa)
          result <- repo.isAlreadySent(rideId, driver1)
        } yield assertTrue(!result)
      },
      test("markSent then isAlreadySent returns true for that (ride, person) pair") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedBaseData(xa)
          _      <- cleanSentConfirmations(xa)
          rideId <- insertRide(xa)
          repo    = PostgresSentConfirmationRequestRepository(xa)
          _      <- repo.markSent(rideId, driver1)
          result <- repo.isAlreadySent(rideId, driver1)
        } yield assertTrue(result)
      },
      test("markSent is idempotent: double-insert does not throw (ON CONFLICT DO NOTHING)") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedBaseData(xa)
          _      <- cleanSentConfirmations(xa)
          rideId <- insertRide(xa)
          repo    = PostgresSentConfirmationRequestRepository(xa)
          _      <- repo.markSent(rideId, driver1)
          _      <- repo.markSent(rideId, driver1) // second call must not fail
          result <- repo.isAlreadySent(rideId, driver1)
        } yield assertTrue(result)
      },
      test("per-person granularity: different persons on the same ride are independent") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedBaseData(xa)
          _      <- cleanSentConfirmations(xa)
          rideId <- insertRide(xa)
          repo    = PostgresSentConfirmationRequestRepository(xa)
          _      <- repo.markSent(rideId, driver1)
          b1     <- repo.isAlreadySent(rideId, driver1) // marked
          b2     <- repo.isAlreadySent(rideId, driver2) // not marked
        } yield assertTrue(b1, !b2)
      },
      test("clear removes records for the given ride but leaves other rides untouched") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedBaseData(xa)
          _       <- cleanSentConfirmations(xa)
          rideId1 <- insertRide(xa)
          rideId2 <- insertRide(xa)
          repo     = PostgresSentConfirmationRequestRepository(xa)
          _       <- repo.markSent(rideId1, driver1)
          _       <- repo.markSent(rideId2, driver1)
          // Clear only ride1
          _       <- repo.clear(rideId1)
          b1      <- repo.isAlreadySent(rideId1, driver1)
          b2      <- repo.isAlreadySent(rideId2, driver1)
        } yield assertTrue(!b1, b2) // ride1 cleared; ride2 unchanged
      },
      test("clear on an empty repo does not fail") {
        val unknownRideId = RideId(UUID.randomUUID())
        for {
          xa  <- ZIO.service[Transactor[Task]]
          _   <- seedBaseData(xa)
          _   <- cleanSentConfirmations(xa)
          repo = PostgresSentConfirmationRequestRepository(xa)
          _   <- repo.clear(unknownRideId)
        } yield assertTrue(true)
      }
    ).provide(PostgresTestContainer.layer) @@
      TestAspect.sequential @@
      TestAspect.withLiveClock @@
      TestAspect.tag("integration")
