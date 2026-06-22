package com.shevchyk.schedule.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.schedule.domain.{DriverUnavailability, DriverUnavailabilityReason}
import com.shevchyk.schedule.repository.PostgresDriverUnavailabilityRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.{Instant, temporal}
import java.util.UUID

/**
 * Integration tests for PostgresDriverUnavailabilityRepository against a real PostgreSQL database running inside a
 * Testcontainer, after migration V10 is applied.
 *
 * Covers:
 *   - create / findById round-trip
 *   - findByDriver (tenant-scoped)
 *   - findByCompanyAndRange (half-open overlap boundaries)
 *   - findOverlapping — touching-edge does NOT overlap; genuine overlap does
 *   - delete — owner+tenant-scoped; wrong tenant is a no-op
 */
object PostgresDriverUnavailabilityRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("00000030-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000030-0000-0000-0000-000000000002"))
  val driverAId      = PersonId(UUID.fromString("00000040-0000-0000-0000-000000000001"))
  val driverBId      = PersonId(UUID.fromString("00000040-0000-0000-0000-000000000002"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${testCompanyId.value}, 'Unavail GmbH', 'unavail-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email)
                 VALUES (${otherCompanyId.value}, 'Other Unavail GmbH', 'other-unavail@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverAId.value}, 'Driver A', 'unavail-driverA@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverBId.value}, 'Driver B', 'unavail-driverB@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanUnavailability(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM driver_unavailability".update.run.transact(xa).unit

  private def ts(epochSeconds: Long): Instant = Instant
    .ofEpochSecond(epochSeconds)
    .truncatedTo(temporal.ChronoUnit.MICROS)

  private def makeRecord(
      id: DriverUnavailabilityId = DriverUnavailabilityId(UUID.randomUUID()),
      driverId: PersonId = driverAId,
      companyId: CompanyId = testCompanyId,
      from: Instant = ts(1_800_000),
      to: Instant = ts(1_804_000),
      reason: DriverUnavailabilityReason = DriverUnavailabilityReason.Lunch,
      note: Option[String] = None
  ): DriverUnavailability = DriverUnavailability(
    id = id,
    driverId = driverId,
    companyId = companyId,
    fromTime = from,
    toTime = to,
    reason = reason,
    note = note,
    createdAt = Instant.now().truncatedTo(temporal.ChronoUnit.MICROS)
  )

  def spec =
    suite("PostgresDriverUnavailabilityRepository")(
      // ── create / findById round-trip ────────────────────────────────────────
      test("create and findById round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanUnavailability(xa)
          repo   = PostgresDriverUnavailabilityRepository(xa)
          rec    = makeRecord(note = Some("test note"))
          _     <- repo.create(rec)
          found <- repo.findById(rec.id)
        } yield assertTrue(
          found.isDefined,
          found.get.id == rec.id,
          found.get.driverId == driverAId,
          found.get.companyId == testCompanyId,
          found.get.fromTime == rec.fromTime,
          found.get.toTime == rec.toTime,
          found.get.reason == DriverUnavailabilityReason.Lunch,
          found.get.note.contains("test note")
        )
      },
      test("findById returns None for unknown id") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanUnavailability(xa)
          repo   = PostgresDriverUnavailabilityRepository(xa)
          found <- repo.findById(DriverUnavailabilityId(UUID.randomUUID()))
        } yield assertTrue(found.isEmpty)
      },
      test("all three reason values round-trip correctly") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanUnavailability(xa)
          repo     = PostgresDriverUnavailabilityRepository(xa)
          lunch    = makeRecord(reason = DriverUnavailabilityReason.Lunch, from = ts(2_000_000), to = ts(2_001_000))
          vacation = makeRecord(reason = DriverUnavailabilityReason.Vacation, from = ts(2_001_000), to = ts(2_002_000))
          personal = makeRecord(reason = DriverUnavailabilityReason.Personal, from = ts(2_002_000), to = ts(2_003_000))
          _       <- repo.create(lunch)
          _       <- repo.create(vacation)
          _       <- repo.create(personal)
          foundL  <- repo.findById(lunch.id)
          foundV  <- repo.findById(vacation.id)
          foundP  <- repo.findById(personal.id)
        } yield assertTrue(
          foundL.get.reason == DriverUnavailabilityReason.Lunch,
          foundV.get.reason == DriverUnavailabilityReason.Vacation,
          foundP.get.reason == DriverUnavailabilityReason.Personal
        )
      },

      // ── findByDriver (tenant-scoped) ────────────────────────────────────────
      test("findByDriver returns only that driver's records for the given company") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <- cleanUnavailability(xa)
          repo  = PostgresDriverUnavailabilityRepository(xa)
          r1    = makeRecord(driverId = driverAId, companyId = testCompanyId, from = ts(3_000_000), to = ts(3_001_000))
          r2    = makeRecord(driverId = driverAId, companyId = testCompanyId, from = ts(3_001_000), to = ts(3_002_000))
          r3    = makeRecord(driverId = driverBId, companyId = testCompanyId, from = ts(3_000_000), to = ts(3_001_000))
          _    <- repo.create(r1)
          _    <- repo.create(r2)
          _    <- repo.create(r3)
          mine <- repo.findByDriver(driverAId, testCompanyId)
        } yield assertTrue(
          mine.length == 2,
          mine.forall(_.driverId == driverAId),
          mine.map(_.id).toSet == Set(r1.id, r2.id)
        )
      },
      // Negative: cross-tenant — using otherCompanyId must return nothing.
      test("findByDriver excludes records belonging to a different company (tenant isolation)") {
        for {
          xa   <- ZIO.service[Transactor[Task]]
          _    <- seedTestData(xa)
          _    <- cleanUnavailability(xa)
          repo  = PostgresDriverUnavailabilityRepository(xa)
          r1    = makeRecord(driverId = driverAId, companyId = testCompanyId, from = ts(4_000_000), to = ts(4_001_000))
          _    <- repo.create(r1)
          // Query same driverId but with the wrong company
          hits <- repo.findByDriver(driverAId, otherCompanyId)
        } yield assertTrue(hits.isEmpty)
      },

      // ── findByCompanyAndRange (half-open overlap) ───────────────────────────
      test("findByCompanyAndRange returns records whose window overlaps the query range") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanUnavailability(xa)
          repo    = PostgresDriverUnavailabilityRepository(xa)
          // Window: [5000, 5100)
          inside  = makeRecord(from = ts(5_020), to = ts(5_060))
          before  = makeRecord(driverId = driverBId, from = ts(4_900), to = ts(4_999))
          after   = makeRecord(driverId = driverBId, from = ts(5_100), to = ts(5_200))
          _      <- repo.create(inside)
          _      <- repo.create(before)
          _      <- repo.create(after)
          result <- repo.findByCompanyAndRange(testCompanyId, ts(5_000), ts(5_100))
        } yield assertTrue(
          result.map(_.id).contains(inside.id),
          !result.map(_.id).contains(before.id),
          !result.map(_.id).contains(after.id)
        )
      },

      // ── findOverlapping — boundary semantics ────────────────────────────────

      // Half-open SQL: from_time < queryTo AND queryFrom < to_time.
      // A record [A, B) and query [B, C) share only the boundary B — NOT an overlap.
      test("touching-edge (record ends exactly where query starts) does NOT overlap") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanUnavailability(xa)
          repo    = PostgresDriverUnavailabilityRepository(xa)
          // Record window: [6_000, 7_000). Query: [7_000, 8_000).
          rec     = makeRecord(from = ts(6_000), to = ts(7_000))
          _      <- repo.create(rec)
          // The record ends at exactly ts(7_000) — the query starts there; no overlap.
          result <- repo.findOverlapping(driverAId, testCompanyId, ts(7_000), ts(8_000))
        } yield assertTrue(result.isEmpty)
      },
      test("touching-edge (query ends exactly where record starts) does NOT overlap") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanUnavailability(xa)
          repo    = PostgresDriverUnavailabilityRepository(xa)
          // Record window: [9_000, 10_000). Query: [8_000, 9_000).
          rec     = makeRecord(from = ts(9_000), to = ts(10_000))
          _      <- repo.create(rec)
          result <- repo.findOverlapping(driverAId, testCompanyId, ts(8_000), ts(9_000))
        } yield assertTrue(result.isEmpty)
      },
      test("genuine overlap: record start inside query window → detected") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanUnavailability(xa)
          repo    = PostgresDriverUnavailabilityRepository(xa)
          // Record: [11_000, 12_000). Query: [10_500, 11_500). Record starts inside query.
          rec     = makeRecord(from = ts(11_000), to = ts(12_000))
          _      <- repo.create(rec)
          result <- repo.findOverlapping(driverAId, testCompanyId, ts(10_500), ts(11_500))
        } yield assertTrue(result.map(_.id).contains(rec.id))
      },
      test("genuine overlap: record completely contains query window → detected") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanUnavailability(xa)
          repo    = PostgresDriverUnavailabilityRepository(xa)
          // Record: [13_000, 16_000). Query: [14_000, 15_000). Record wraps query.
          rec     = makeRecord(from = ts(13_000), to = ts(16_000))
          _      <- repo.create(rec)
          result <- repo.findOverlapping(driverAId, testCompanyId, ts(14_000), ts(15_000))
        } yield assertTrue(result.map(_.id).contains(rec.id))
      },
      // Negative tenant isolation: findOverlapping scoped to one driver+company.
      test("findOverlapping excludes records from a different company (tenant isolation)") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanUnavailability(xa)
          repo    = PostgresDriverUnavailabilityRepository(xa)
          rec     = makeRecord(
                      driverId = driverAId,
                      companyId = testCompanyId,
                      from = ts(20_000),
                      to = ts(21_000)
                    )
          _      <- repo.create(rec)
          result <- repo.findOverlapping(driverAId, otherCompanyId, ts(19_000), ts(22_000))
        } yield assertTrue(result.isEmpty)
      },
      test("findOverlapping excludes records from a different driver") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanUnavailability(xa)
          repo    = PostgresDriverUnavailabilityRepository(xa)
          rec     = makeRecord(driverId = driverAId, from = ts(25_000), to = ts(26_000))
          _      <- repo.create(rec)
          result <- repo.findOverlapping(driverBId, testCompanyId, ts(24_000), ts(27_000))
        } yield assertTrue(result.isEmpty)
      },

      // ── delete (owner+tenant-scoped) ────────────────────────────────────────
      test("delete removes the record when owner and company match") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanUnavailability(xa)
          repo   = PostgresDriverUnavailabilityRepository(xa)
          rec    = makeRecord(from = ts(30_000), to = ts(31_000))
          _     <- repo.create(rec)
          _     <- repo.delete(rec.id, driverAId, testCompanyId)
          found <- repo.findById(rec.id)
        } yield assertTrue(found.isEmpty)
      },
      test("delete with wrong companyId is a no-op (record remains — tenant isolation)") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanUnavailability(xa)
          repo   = PostgresDriverUnavailabilityRepository(xa)
          rec    = makeRecord(from = ts(32_000), to = ts(33_000))
          _     <- repo.create(rec)
          _     <- repo.delete(rec.id, driverAId, otherCompanyId) // wrong company
          found <- repo.findById(rec.id)
        } yield assertTrue(found.isDefined)
      },
      test("delete with wrong driverId is a no-op (record remains — owner check)") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanUnavailability(xa)
          repo   = PostgresDriverUnavailabilityRepository(xa)
          rec    = makeRecord(from = ts(34_000), to = ts(35_000))
          _     <- repo.create(rec)
          _     <- repo.delete(rec.id, driverBId, testCompanyId) // wrong driver
          found <- repo.findById(rec.id)
        } yield assertTrue(found.isDefined)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
