package com.shevchyk.notification.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.notification.repository.PostgresEtaAlertRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Integration tests for PostgresEtaAlertRepository against a real PostgreSQL via
 * Testcontainers. Covers the dedup round-trip (markAlerted / isAlreadyAlerted /
 * clear) and per-driver granularity that the SQL layer enforces.
 */
object PostgresEtaAlertRepositorySpec extends ZIOSpecDefault:

  private val company  = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000c1"))
  private val client   = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000c1"))
  private val driver1  = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000d1"))
  private val driver2  = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000d2"))

  private def seed(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${company.value}, 'C', 'c@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${client.value}, 'Client', 'cl@test.com', 'client'::person_role, ${company.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driver1.value}, 'D1', 'd1@test.com', 'driver'::person_role, ${company.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driver2.value}, 'D2', 'd2@test.com', 'driver'::person_role, ${company.value}, 'x')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def seedRide(xa: Transactor[Task]): Task[RideId] =
    val rideId = RideId(UUID.randomUUID())
    sql"""INSERT INTO rides (id, client_id, creator_id, company_id, from_address, to_address, pickup_datetime)
          VALUES (${rideId.value}, ${client.value}, ${client.value}, ${company.value},
                  'Marienplatz', 'Airport', ${Instant.now()})"""
      .update.run.transact(xa).as(rideId)

  private def clean(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM eta_alerts".update.run.transact(xa).unit

  def spec =
    suite("PostgresEtaAlertRepository")(
      test("markAlerted then isAlreadyAlerted reports true") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          ride   <- seedRide(xa)
          repo    = PostgresEtaAlertRepository(xa)
          before <- repo.isAlreadyAlerted(ride, driver1)
          _      <- repo.markAlerted(ride, driver1)
          after  <- repo.isAlreadyAlerted(ride, driver1)
        } yield assertTrue(!before, after)
      },
      test("markAlerted is idempotent (ON CONFLICT DO NOTHING)") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seed(xa)
          _    <- clean(xa)
          ride <- seedRide(xa)
          repo  = PostgresEtaAlertRepository(xa)
          _    <- repo.markAlerted(ride, driver1)
          _    <- repo.markAlerted(ride, driver1) // must not throw on duplicate PK
          seen <- repo.isAlreadyAlerted(ride, driver1)
        } yield assertTrue(seen)
      },
      test("dedup is per (ride, driver): another driver is not yet alerted") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seed(xa)
          _     <- clean(xa)
          ride  <- seedRide(xa)
          repo   = PostgresEtaAlertRepository(xa)
          _     <- repo.markAlerted(ride, driver1)
          d1    <- repo.isAlreadyAlerted(ride, driver1)
          d2    <- repo.isAlreadyAlerted(ride, driver2)
        } yield assertTrue(d1, !d2)
      },
      test("clear removes the alert so a fresh one can be sent") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seed(xa)
          _      <- clean(xa)
          ride   <- seedRide(xa)
          repo    = PostgresEtaAlertRepository(xa)
          _      <- repo.markAlerted(ride, driver1)
          _      <- repo.clear(ride)
          after  <- repo.isAlreadyAlerted(ride, driver1)
        } yield assertTrue(!after)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
