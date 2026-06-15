package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.PostgresRideTemplateRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.temporal.ChronoUnit
import java.time.{Instant, LocalTime}
import java.util.UUID

/**
 * Integration tests for PostgresRideTemplateRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresRideTemplateRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("00000060-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000060-0000-0000-0000-000000000002"))
  val clientId       = PersonId(UUID.fromString("00000061-0000-0000-0000-000000000001"))
  val creatorId      = PersonId(UUID.fromString("00000061-0000-0000-0000-000000000002"))
  val driverId       = PersonId(UUID.fromString("00000061-0000-0000-0000-000000000003"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Tpl GmbH', 'tpl-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${otherCompanyId.value}, 'Tpl Other GmbH', 'tpl-other@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientId.value}, 'Tpl Client', 'tpl-client@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${creatorId.value}, 'Tpl Creator', 'tpl-creator@test.com', 'secretary'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverId.value}, 'Tpl Driver', 'tpl-driver@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanTemplates(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM ride_templates".update.run.transact(xa).unit

  private def makeTemplate(
      id: RideTemplateId = RideTemplateId.generate(),
      company: CompanyId = testCompanyId,
      name: String = "Daily airport",
      isActive: Boolean = true,
      recurrence: RecurrencePattern = RecurrencePattern.DAILY,
      preferredDriver: Option[PersonId] = Some(driverId),
      price: Option[BigDecimal] = Some(BigDecimal("55.00"))
  ): RideTemplate = RideTemplate(
    id = id,
    companyId = company,
    clientId = clientId,
    creatorId = creatorId,
    name = name,
    fromAddress = "Home 1",
    fromLat = Some(48.1),
    fromLng = Some(11.5),
    toAddress = "MUC Airport",
    toLat = Some(48.35),
    toLng = Some(11.78),
    preferredDriverId = preferredDriver,
    notes = Some("ring bell"),
    recurrencePattern = recurrence,
    recurrenceDays = Some("MON,WED"),
    pickupTime = LocalTime.of(8, 30),
    isActive = isActive,
    flightNumber = Some("LH123"),
    isAirportTransfer = true,
    price = price,
    createdAt = Instant.now().truncatedTo(ChronoUnit.MICROS),
    updatedAt = Instant.now().truncatedTo(ChronoUnit.MICROS)
  )

  def spec =
    suite("PostgresRideTemplateRepository")(
      test("create and findById round-trip preserves all fields") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanTemplates(xa)
          repo   = PostgresRideTemplateRepository(xa)
          tpl    = makeTemplate()
          _     <- repo.create(tpl)
          found <- repo.findById(tpl.id)
        } yield assertTrue(
          found.isDefined,
          found.get.id == tpl.id,
          found.get.companyId == testCompanyId,
          found.get.clientId == clientId,
          found.get.creatorId == creatorId,
          found.get.name == "Daily airport",
          found.get.fromAddress == "Home 1",
          found.get.fromLat.contains(48.1),
          found.get.toAddress == "MUC Airport",
          found.get.preferredDriverId.contains(driverId),
          found.get.notes.contains("ring bell"),
          found.get.recurrencePattern == RecurrencePattern.DAILY,
          found.get.recurrenceDays.contains("MON,WED"),
          found.get.pickupTime == LocalTime.of(8, 30),
          found.get.isActive,
          found.get.flightNumber.contains("LH123"),
          found.get.isAirportTransfer,
          found.get.price.contains(BigDecimal("55.00"))
        )
      },
      test("findByCompanyId isolates by company") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanTemplates(xa)
          repo   = PostgresRideTemplateRepository(xa)
          _     <- repo.create(makeTemplate(company = testCompanyId, preferredDriver = None))
          _     <- repo.create(makeTemplate(company = testCompanyId, preferredDriver = None))
          _     <- repo.create(makeTemplate(company = otherCompanyId, preferredDriver = None))
          mine  <- repo.findByCompanyId(testCompanyId)
          other <- repo.findByCompanyId(otherCompanyId)
        } yield assertTrue(
          mine.length == 2,
          mine.forall(_.companyId == testCompanyId),
          other.length == 1
        )
      },
      test("findActiveByCompanyId returns only active templates") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanTemplates(xa)
          repo    = PostgresRideTemplateRepository(xa)
          _      <- repo.create(makeTemplate(name = "Active", isActive = true, preferredDriver = None))
          _      <- repo.create(makeTemplate(name = "Inactive", isActive = false, preferredDriver = None))
          active <- repo.findActiveByCompanyId(testCompanyId)
        } yield assertTrue(
          active.length == 1,
          active.head.name == "Active",
          active.forall(_.isActive)
        )
      },
      test("update changes fields") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanTemplates(xa)
          repo   = PostgresRideTemplateRepository(xa)
          tpl    = makeTemplate(name = "Before", price = Some(BigDecimal("10.00")))
          _     <- repo.create(tpl)
          upd    = tpl.copy(
                     name = "After",
                     price = Some(BigDecimal("99.00")),
                     pickupTime = LocalTime.of(7, 0),
                     recurrencePattern = RecurrencePattern.WEEKDAYS,
                     preferredDriverId = None
                   )
          _     <- repo.update(upd)
          found <- repo.findById(tpl.id)
        } yield assertTrue(
          found.get.name == "After",
          found.get.price.contains(BigDecimal("99.00")),
          found.get.pickupTime == LocalTime.of(7, 0),
          found.get.recurrencePattern == RecurrencePattern.WEEKDAYS,
          found.get.preferredDriverId.isEmpty
        )
      },
      test("deactivate sets is_active false") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanTemplates(xa)
          repo    = PostgresRideTemplateRepository(xa)
          tpl     = makeTemplate(isActive = true, preferredDriver = None)
          _      <- repo.create(tpl)
          ok     <- repo.deactivate(tpl.id)
          missing <- repo.deactivate(RideTemplateId.generate())
          found  <- repo.findById(tpl.id)
        } yield assertTrue(
          ok,
          !missing,
          found.isDefined,
          !found.get.isActive
        )
      },
      test("delete removes template") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanTemplates(xa)
          repo     = PostgresRideTemplateRepository(xa)
          tpl      = makeTemplate(preferredDriver = None)
          _       <- repo.create(tpl)
          deleted <- repo.delete(tpl.id)
          missing <- repo.delete(RideTemplateId.generate())
          found   <- repo.findById(tpl.id)
        } yield assertTrue(deleted, !missing, found.isEmpty)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
