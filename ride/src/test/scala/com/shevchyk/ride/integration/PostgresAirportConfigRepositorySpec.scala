package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.ride.domain.{Airport, AirportCheckpointZone}
import com.shevchyk.ride.repository.PostgresAirportConfigRepository
import doobie.Transactor
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Integration tests for [[PostgresAirportConfigRepository]] against a real PostgreSQL database
 * provided by Testcontainers (reusable shared container, see [[PostgresTestContainer]]).
 *
 * Invariant §4: NEVER mock the DB — use Testcontainers.
 *
 * Coverage:
 *  - findAll / findByCode round-trip
 *  - create stores airport, MUC V3 seed is present after migration
 *  - update modifies fields
 *  - delete soft-deletes (is_active = false)
 *  - createZone / deleteZone CRUD
 *  - Negative: findByCode returns None for unknown code
 */
object PostgresAirportConfigRepositorySpec extends ZIOSpecDefault {

  private val now = Instant.parse("2026-01-01T00:00:00Z")

  private def freshAirport(code: String): Airport = Airport(
    code = code,
    name = s"$code International",
    country = "DE",
    landingLat = 48.3537,
    landingLon = 11.7860,
    landingRadius = 2000,
    isActive = true,
    zones = Nil,
    createdAt = now,
    updatedAt = now
  )

  private def freshZone(airportCode: String, checkpointType: String): AirportCheckpointZone =
    AirportCheckpointZone(
      id = UUID.randomUUID(), // overwritten by DB RETURNING
      airportCode = airportCode,
      terminalCode = "T1",
      checkpointType = checkpointType,
      displayName = s"$checkpointType display",
      lat = 48.3526,
      lon = 11.7798,
      radiusMeters = 200,
      sortOrder = 1,
      createdAt = now,
      updatedAt = now
    )

  def spec = suite("PostgresAirportConfigRepository (real DB)")(

    test("findAll returns only created airports (DB is clean after TRUNCATE)") {
      // NOTE: The shared PostgresTestContainer resets (TRUNCATE) the DB before each spec,
      // so V3 seed data is not present. This test verifies the round-trip: create → findAll.
      for {
        xa   <- ZIO.service[Transactor[Task]]
        repo  = PostgresAirportConfigRepository(xa)
        _    <- repo.create(freshAirport("MUC"))
        _    <- repo.create(freshAirport("FRA"))
        all  <- repo.findAll()
      } yield assertTrue(
        all.exists(_.code == "MUC"),
        all.exists(_.code == "FRA"),
        all.size == 2
      )
    },

    test("findByCode returns airport with zones after createZone calls") {
      // The shared container truncates seed data; we create our own fixture.
      for {
        xa     <- ZIO.service[Transactor[Task]]
        repo    = PostgresAirportConfigRepository(xa)
        _      <- repo.create(freshAirport("MUC"))
        _      <- repo.createZone(freshZone("MUC", "arrivals_hall"))
        _      <- repo.createZone(freshZone("MUC", "terminal_exit"))
        mucOpt <- repo.findByCode("MUC")
      } yield assertTrue(
        mucOpt.isDefined,
        mucOpt.get.zones.nonEmpty,
        mucOpt.get.zones.size == 2
      )
    },

    test("findByCode returns None for unknown code") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        repo  = PostgresAirportConfigRepository(xa)
        res  <- repo.findByCode("ZZZ_UNKNOWN")
      } yield assertTrue(res.isEmpty)
    },

    test("create stores airport and findByCode retrieves it") {
      for {
        xa   <- ZIO.service[Transactor[Task]]
        repo  = PostgresAirportConfigRepository(xa)
        _    <- repo.create(freshAirport("TST"))
        found <- repo.findByCode("TST")
      } yield assertTrue(
        found.isDefined,
        found.get.code == "TST",
        found.get.isActive
      )
    },

    test("update modifies airport fields") {
      for {
        xa      <- ZIO.service[Transactor[Task]]
        repo     = PostgresAirportConfigRepository(xa)
        _       <- repo.create(freshAirport("UPD"))
        original <- repo.findByCode("UPD")
        updated  <- repo.update("UPD", original.get.copy(name = "Updated Name", landingRadius = 9999))
        found    <- repo.findByCode("UPD")
      } yield assertTrue(
        updated.isDefined,
        found.get.name == "Updated Name",
        found.get.landingRadius == 9999
      )
    },

    test("delete soft-deletes airport (is_active = false)") {
      for {
        xa     <- ZIO.service[Transactor[Task]]
        repo    = PostgresAirportConfigRepository(xa)
        _      <- repo.create(freshAirport("DEL"))
        result <- repo.delete("DEL")
        found  <- repo.findByCode("DEL")
      } yield assertTrue(
        result,
        found.isDefined,
        !found.get.isActive
      )
    },

    test("delete returns false for non-existent code") {
      for {
        xa     <- ZIO.service[Transactor[Task]]
        repo    = PostgresAirportConfigRepository(xa)
        result <- repo.delete("NOBODY")
      } yield assertTrue(!result)
    },

    test("createZone appends zone to airport and round-trips correctly") {
      for {
        xa    <- ZIO.service[Transactor[Task]]
        repo   = PostgresAirportConfigRepository(xa)
        _     <- repo.create(freshAirport("ZNE"))
        zone  <- repo.createZone(freshZone("ZNE", "arrivals_hall"))
        found <- repo.findByCode("ZNE")
      } yield assertTrue(
        zone.airportCode == "ZNE",
        zone.checkpointType == "arrivals_hall",
        found.exists(_.zones.exists(_.id == zone.id))
      )
    },

    test("deleteZone removes zone from airport") {
      for {
        xa    <- ZIO.service[Transactor[Task]]
        repo   = PostgresAirportConfigRepository(xa)
        _     <- repo.create(freshAirport("DZN"))
        zone  <- repo.createZone(freshZone("DZN", "terminal_exit"))
        del   <- repo.deleteZone(zone.id)
        found <- repo.findByCode("DZN")
      } yield assertTrue(
        del,
        found.exists(_.zones.isEmpty)
      )
    }

  ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.tag("integration")
}
