package com.shevchyk.ride.application

import com.shevchyk.core.config.AirportPickupConfig
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{
  ClientCompanyRepository,
  CompanySettingsRepository,
  InMemoryClientCompanyRepository,
  InMemoryCompanySettingsRepository
}
import com.shevchyk.ride.application.service.{PickupTimeService, PickupTimeResult}
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Unit tests for PickupTimeService — pure resolution functions and the Live implementation.
 *
 * Coverage:
 *   - Resolution override matrix: all-None → global; company override; client override; client partial; company but no
 *     client company.
 *   - Formula arithmetic: exact Instant for known values.
 *   - HERE returns Some(n) → travelTimeFallback = false.
 *   - HERE returns None → Haversine used → travelTimeFallback = true.
 *
 * Mutation-verified branches:
 *   - departure-guard / isArrival=false (no business logic here — covered in RideServicePickupTimeSpec)
 *   - client.flatMap(_.airportBufferMinutes) resolution: "client override" test kills the mutation "swap client with
 *     company" (client buffer 10, company buffer 20 — swapping yields 20 not 10)
 *   - company.flatMap(_.airportBufferMinutes) resolution: "company override" test kills "skip company, return global"
 *     mutation (company buffer 20 ≠ global 15)
 *   - .getOrElse(global.defaultBufferMinutes): "all-None → global" kills "hardcode 0" mutation
 *   - HERE-None path: "HERE unavailable" test kills "always use HERE" mutation (travelTimeFallback would be false)
 *   - HERE-Some path: "HERE available" test kills "always use Haversine" mutation (travelTimeFallback would be true)
 */
object PickupTimeServiceSpec extends ZIOSpecDefault {

  // ── IDs ─────────────────────────────────────────────────────────────────

  val companyId      = CompanyId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("bbbbbbbb-0000-0000-0000-000000000001"))
  val clientCcId     = ClientCompanyId(UUID.fromString("cccccccc-0000-0000-0000-000000000001"))
  val foreignCcId    = ClientCompanyId(UUID.fromString("dddddddd-0000-0000-0000-000000000001"))

  // ── Global config: defaults 15/60 ────────────────────────────────────────

  val globalDefaults = AirportPickupConfig(defaultBufferMinutes = 15, defaultCheckInCloseMinutes = 60)

  // ── Helpers ──────────────────────────────────────────────────────────────

  def makeSettings(
      compId: CompanyId = companyId,
      bufferMinutes: Option[Int] = None,
      checkInCloseMinutes: Option[Int] = None
  ): CompanySettings = CompanySettings(
    companyId = compId,
    airportBufferMinutes = bufferMinutes,
    airportCheckInCloseMinutes = checkInCloseMinutes
  )

  def makeClientCompany(
      ccId: ClientCompanyId = clientCcId,
      taxiCompanyId: CompanyId = companyId,
      bufferMinutes: Option[Int] = None,
      checkInCloseMinutes: Option[Int] = None
  ): ClientCompany = ClientCompany(
    id = ccId,
    name = "Test Corp",
    taxiCompanyId = taxiCompanyId,
    airportBufferMinutes = bufferMinutes,
    airportCheckInCloseMinutes = checkInCloseMinutes
  )

  // ── Controllable TravelTimeService stub ──────────────────────────────────

  def stubTravelTime(result: Option[Int]): ZLayer[Any, Nothing, TravelTimeService] = ZLayer.succeed(
    new TravelTimeService:
      def travelMinutes(fromLat: Double, fromLng: Double, toLat: Double, toLng: Double): Task[Option[Int]] = ZIO
        .succeed(result)
  )

  // ── Layer assembly helper ────────────────────────────────────────────────

  def buildService(
      companySettings: Option[CompanySettings] = None,
      clientCompany: Option[ClientCompany] = None,
      travelTime: Option[Int] = Some(30) // HERE returns 30 min by default
  ): ZLayer[Any, Nothing, PickupTimeService] = {
    val settingsLayer: ZLayer[Any, Nothing, CompanySettingsRepository] = ZLayer.fromZIO(
      ZIO.succeed {
        val repo = new InMemoryCompanySettingsRepository
        companySettings.foreach(s =>
          Unsafe.unsafe(implicit u => Runtime.default.unsafe.run(repo.upsert(s)).getOrThrow())
        )
        repo: CompanySettingsRepository
      }
    )
    val clientCcLayer: ZLayer[Any, Nothing, ClientCompanyRepository]   = ZLayer.fromZIO(
      ZIO.succeed {
        val repo = new InMemoryClientCompanyRepository
        clientCompany.foreach(cc =>
          Unsafe.unsafe(implicit u => Runtime.default.unsafe.run(repo.create(cc)).getOrThrow())
        )
        repo: ClientCompanyRepository
      }
    )
    (settingsLayer ++
      clientCcLayer ++
      stubTravelTime(travelTime) ++
      ZLayer.succeed(globalDefaults)) >+> PickupTimeService.layer
  }

  // ── Coordinates for tests: Munich city (pickup) → MUC Airport (dropoff) ─

  val pickupLat        = 48.1351
  val pickupLng        = 11.5820
  val dropoffLat       = 48.3537
  val dropoffLng       = 11.7750
  // Haversine distance ≈ 30 km → ceil(30/50*60)=36 min
  val haversineMinutes = PickupTimeService.haversineTravelMinutes(pickupLat, pickupLng, dropoffLat, dropoffLng)

  // Reference flight departure: 2030-06-15T12:00:00Z
  val flightDep = Instant.parse("2030-06-15T12:00:00Z")

  def spec =
    suite("PickupTimeService")(
      suite("Pure resolution functions — PickupTimeService.resolveBuffer / resolveCheckIn")(
        test("all-None → global defaults (buffer=15, checkIn=60)") {
          // Mutation-verified: kills "return 0" and "return company" mutations on getOrElse
          val result =
            for {
              buf     <- ZIO.succeed(PickupTimeService.resolveBuffer(None, None, globalDefaults))
              checkIn <- ZIO.succeed(PickupTimeService.resolveCheckIn(None, None, globalDefaults))
            } yield assertTrue(buf == 15, checkIn == 60)
          result
        },
        test("company override (buffer=20, checkIn=45) overrides global defaults") {
          // Mutation-verified: kills "skip company" → would return global 15, not company 20
          val company = Some(makeSettings(bufferMinutes = Some(20), checkInCloseMinutes = Some(45)))
          val buf     = PickupTimeService.resolveBuffer(None, company, globalDefaults)
          val checkIn = PickupTimeService.resolveCheckIn(None, company, globalDefaults)
          assertTrue(buf == 20, checkIn == 45)
        },
        test("client override (buffer=10, checkIn=30) overrides company AND global") {
          // Mutation-verified: kills "swap client with company" → client buffer 10 ≠ company buffer 20
          val company = Some(makeSettings(bufferMinutes = Some(20), checkInCloseMinutes = Some(45)))
          val client  = Some(makeClientCompany(bufferMinutes = Some(10), checkInCloseMinutes = Some(30)))
          val buf     = PickupTimeService.resolveBuffer(client, company, globalDefaults)
          val checkIn = PickupTimeService.resolveCheckIn(client, company, globalDefaults)
          assertTrue(buf == 10, checkIn == 30)
        },
        test("client partial: client sets buffer=10, checkIn inherited from company=45") {
          // Mutation-verified: kills "always use client for checkIn" → would return None→global 60, not company 45
          val company = Some(makeSettings(bufferMinutes = Some(20), checkInCloseMinutes = Some(45)))
          val client  = Some(makeClientCompany(bufferMinutes = Some(10), checkInCloseMinutes = None))
          val buf     = PickupTimeService.resolveBuffer(client, company, globalDefaults)
          val checkIn = PickupTimeService.resolveCheckIn(client, company, globalDefaults)
          // buffer from client=10; checkIn from company=45 (client has None)
          assertTrue(buf == 10, checkIn == 45)
        },
        test("company set but no client company: company values win over global") {
          val company = Some(makeSettings(bufferMinutes = Some(20), checkInCloseMinutes = Some(45)))
          val buf     = PickupTimeService.resolveBuffer(None, company, globalDefaults)
          val checkIn = PickupTimeService.resolveCheckIn(None, company, globalDefaults)
          assertTrue(buf == 20, checkIn == 45)
        }
      ),
      suite("Pure formula — PickupTimeService.computePickup")(
        test("formula: flightDep − checkIn − travel − buffer = pickupTime (exact Instant)") {
          // flight=2030-06-15T12:00:00Z, checkIn=60, travel=30, buffer=15 → 12:00 - 105 min = 10:15:00Z
          val checkIn   = 60
          val travelMin = 30
          val buffer    = 15
          val expected  = Instant.parse("2030-06-15T10:15:00Z")
          val result    = PickupTimeService.computePickup(flightDep, checkIn, travelMin, buffer)
          assertTrue(result == expected)
        },
        test("formula with checkIn=0, travel=0, buffer=0 → equals flightDep") {
          val result = PickupTimeService.computePickup(flightDep, 0, 0, 0)
          assertTrue(result == flightDep)
        }
      ),
      suite("Live.computePickupTime")(
        test("HERE returns Some(30) → travelTimeFallback=false, travelMinutes=30") {
          // Mutation-verified: kills "always return travelTimeFallback=true" mutation
          for {
            svc    <- ZIO.service[PickupTimeService]
            result <- svc.computePickupTime(companyId, None, flightDep, pickupLat, pickupLng, dropoffLat, dropoffLng)
          } yield assertTrue(
            !result.travelTimeFallback,
            result.travelMinutes == 30
          )
        }.provide(buildService(travelTime = Some(30))),
        test("HERE returns None → Haversine used → travelTimeFallback=true") {
          // Mutation-verified: kills "always return travelTimeFallback=false" mutation
          for {
            svc    <- ZIO.service[PickupTimeService]
            result <- svc.computePickupTime(companyId, None, flightDep, pickupLat, pickupLng, dropoffLat, dropoffLng)
          } yield assertTrue(
            result.travelTimeFallback,
            result.travelMinutes == haversineMinutes,
            result.travelMinutes > 0
          )
        }.provide(buildService(travelTime = None)),
        test("HERE Some(30) + global defaults → exact pickup Instant") {
          // flight=2030-06-15T12:00:00Z, global buffer=15, global checkIn=60, travel=30
          // expected: 12:00 - (15+30+60)×60s = 12:00 - 105min = 10:15:00Z
          val expected = Instant.parse("2030-06-15T10:15:00Z")
          for {
            svc    <- ZIO.service[PickupTimeService]
            result <- svc.computePickupTime(companyId, None, flightDep, pickupLat, pickupLng, dropoffLat, dropoffLng)
          } yield assertTrue(result.pickupDateTime == expected, result.bufferMinutes == 15, result.checkInClose == 60)
        }.provide(buildService(travelTime = Some(30))),
        test("company override applied: buffer=20, checkIn=45, travel=30 → exact Instant") {
          // expected: 12:00 - (20+30+45)*60s = 12:00 - 95min = 10:25:00Z
          val expected = Instant.parse("2030-06-15T10:25:00Z")
          for {
            svc    <- ZIO.service[PickupTimeService]
            result <- svc.computePickupTime(companyId, None, flightDep, pickupLat, pickupLng, dropoffLat, dropoffLng)
          } yield assertTrue(result.pickupDateTime == expected, result.bufferMinutes == 20, result.checkInClose == 45)
        }.provide(
          buildService(
            companySettings = Some(makeSettings(bufferMinutes = Some(20), checkInCloseMinutes = Some(45))),
            travelTime = Some(30)
          )
        ),
        test("client override applied: client buffer=10, client checkIn=30, travel=30 → exact Instant") {
          // expected: 12:00 - (10+30+30)*60s = 12:00 - 70min = 10:50:00Z
          val expected = Instant.parse("2030-06-15T10:50:00Z")
          for {
            svc    <- ZIO.service[PickupTimeService]
            result <- svc.computePickupTime(
                        companyId,
                        Some(clientCcId),
                        flightDep,
                        pickupLat,
                        pickupLng,
                        dropoffLat,
                        dropoffLng
                      )
          } yield assertTrue(result.pickupDateTime == expected, result.bufferMinutes == 10, result.checkInClose == 30)
        }.provide(
          buildService(
            companySettings = Some(makeSettings(bufferMinutes = Some(20), checkInCloseMinutes = Some(45))),
            clientCompany = Some(makeClientCompany(bufferMinutes = Some(10), checkInCloseMinutes = Some(30))),
            travelTime = Some(30)
          )
        ),
        test("client partial override: client buffer=10, checkIn inherited from company=45") {
          // expected: 12:00 - (10+30+45)*60s = 12:00 - 85min = 10:35:00Z
          val expected = Instant.parse("2030-06-15T10:35:00Z")
          for {
            svc    <- ZIO.service[PickupTimeService]
            result <- svc.computePickupTime(
                        companyId,
                        Some(clientCcId),
                        flightDep,
                        pickupLat,
                        pickupLng,
                        dropoffLat,
                        dropoffLng
                      )
          } yield assertTrue(result.pickupDateTime == expected, result.bufferMinutes == 10, result.checkInClose == 45)
        }.provide(
          buildService(
            companySettings = Some(makeSettings(bufferMinutes = Some(20), checkInCloseMinutes = Some(45))),
            clientCompany = Some(makeClientCompany(bufferMinutes = Some(10), checkInCloseMinutes = None)),
            travelTime = Some(30)
          )
        ),
        test("foreign client company (different taxiCompanyId) is silently ignored → company settings used") {
          // clientCcId belongs to otherCompanyId, but request is for companyId → client overrides must NOT apply
          // Expected: company buffer=20, company checkIn=45, travel=30 → 12:00-95min=10:25:00Z
          val expected = Instant.parse("2030-06-15T10:25:00Z")
          for {
            svc    <- ZIO.service[PickupTimeService]
            result <- svc.computePickupTime(
                        companyId, // JWT company
                        Some(clientCcId),
                        flightDep,
                        pickupLat,
                        pickupLng,
                        dropoffLat,
                        dropoffLng
                      )
          } yield assertTrue(result.pickupDateTime == expected, result.bufferMinutes == 20, result.checkInClose == 45)
        }.provide(
          buildService(
            companySettings = Some(makeSettings(bufferMinutes = Some(20), checkInCloseMinutes = Some(45))),
            clientCompany = Some(
              makeClientCompany(
                ccId = clientCcId,
                taxiCompanyId = otherCompanyId,
                bufferMinutes = Some(5),
                checkInCloseMinutes = Some(10)
              )
            ),
            travelTime = Some(30)
          )
        )
      ),
      suite("Haversine fallback")(
        test("haversineTravelMinutes returns at least 1 minute for same-location input") {
          val result = PickupTimeService.haversineTravelMinutes(0.0, 0.0, 0.0, 0.0)
          assertTrue(result >= 1)
        },
        test("haversineTravelMinutes Munich→MUC is roughly 36 minutes at 50 km/h") {
          // distance ≈ 30km → ceil(30/50*60)=36
          val result = PickupTimeService.haversineTravelMinutes(pickupLat, pickupLng, dropoffLat, dropoffLng)
          assertTrue(result >= 30, result <= 45) // reasonable bounds
        }
      )
    )
}
