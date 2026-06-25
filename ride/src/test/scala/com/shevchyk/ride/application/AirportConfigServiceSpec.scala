package com.shevchyk.ride.application

import com.shevchyk.ride.application.service.AirportConfigService
import com.shevchyk.ride.domain.{Airport, AirportCheckpoint, AirportCheckpointZone, RideError}
import com.shevchyk.ride.repository.InMemoryAirportConfigRepository
import zio.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Unit tests for [[AirportConfigService]] using [[InMemoryAirportConfigRepository]].
 *
 * Coverage target (per plan §6 / test table rows #7):
 *   - createAirport stores and getAirport retrieves
 *   - getLandingGeofence returns correct triple for a known code, None for an unknown one
 *   - getCheckpointDisplayName defaults to enum name when no zone matches
 *   - deleteAirport soft-deletes (returns true, subsequent getAirport returns inactive)
 */
object AirportConfigServiceSpec extends ZIOSpecDefault {

  // ─── Fixtures ────────────────────────────────────────────────────────────────

  private val now = Instant.parse("2026-01-01T00:00:00Z")

  private def makeAirport(code: String, zones: List[AirportCheckpointZone] = Nil): Airport = Airport(
    code = code,
    name = s"$code International",
    country = "DE",
    landingLat = 48.3537,
    landingLon = 11.7860,
    landingRadius = 2000,
    isActive = true,
    zones = zones,
    createdAt = now,
    updatedAt = now
  )

  private def makeZone(airportCode: String, checkpointType: String, displayName: String): AirportCheckpointZone =
    AirportCheckpointZone(
      id = UUID.randomUUID(),
      airportCode = airportCode,
      terminalCode = "T1",
      checkpointType = checkpointType,
      displayName = displayName,
      lat = 48.3526,
      lon = 11.7798,
      radiusMeters = 200,
      sortOrder = 1,
      createdAt = now,
      updatedAt = now
    )

  // ─── Layer wiring ─────────────────────────────────────────────────────────────

  private val freshServiceLayer: ZLayer[Any, Nothing, AirportConfigService] =
    ZLayer.succeed[com.shevchyk.ride.repository.AirportConfigRepository](
      new InMemoryAirportConfigRepository
    ) >>> AirportConfigService.layer

  // ─── Spec ─────────────────────────────────────────────────────────────────────

  def spec =
    suite("AirportConfigService")(
      suite("createAirport / getAirport")(
        test("createAirport stores the airport and getAirport retrieves it") {
          for {
            svc       <- ZIO.service[AirportConfigService]
            airport    = makeAirport("MUC")
            created   <- svc.createAirport(airport)
            retrieved <- svc.getAirport("MUC")
          } yield assertTrue(
            created.code == "MUC",
            retrieved.isDefined,
            retrieved.get.name == "MUC International",
            retrieved.get.isActive
          )
        },
        test("getAirport returns None for unknown code") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            result <- svc.getAirport("XYZ")
          } yield assertTrue(result.isEmpty)
        },
        test("listAirports returns all created airports") {
          for {
            svc  <- ZIO.service[AirportConfigService]
            _    <- svc.createAirport(makeAirport("MUC"))
            _    <- svc.createAirport(makeAirport("BER"))
            list <- svc.listAirports()
          } yield assertTrue(
            list.size == 2,
            list.exists(_.code == "MUC"),
            list.exists(_.code == "BER")
          )
        }
      ).provide(freshServiceLayer),
      suite("getLandingGeofence")(
        test("returns correct triple (lat, lon, radius) for a known active airport") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            airport = Airport(
                        code = "MUC",
                        name = "München",
                        country = "DE",
                        landingLat = 48.3537,
                        landingLon = 11.7860,
                        landingRadius = 2000,
                        isActive = true,
                        zones = Nil,
                        createdAt = now,
                        updatedAt = now
                      )
            _      <- svc.createAirport(airport)
            result <- svc.getLandingGeofence("MUC")
          } yield assertTrue(
            result.isDefined,
            result.get._1 == 48.3537,
            result.get._2 == 11.7860,
            result.get._3 == 2000
          )
        },
        test("returns None for an unknown airport code") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            result <- svc.getLandingGeofence("ZZZ")
          } yield assertTrue(result.isEmpty)
        },
        test("returns None for a soft-deleted (inactive) airport after deleteAirport") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            airport = makeAirport("FRA")
            _      <- svc.createAirport(airport)
            _      <- svc.deleteAirport("FRA")
            // cache is invalidated on delete; next read fetches fresh data
            result <- svc.getLandingGeofence("FRA")
          } yield assertTrue(result.isEmpty)
        }
      ).provide(freshServiceLayer),
      suite("getCheckpointDisplayName")(
        test("returns zone displayName when a matching zone exists") {
          for {
            svc  <- ZIO.service[AirportConfigService]
            zone  = makeZone("MUC", "arrivals_hall", "T1 Arrivals Hall")
            air   = makeAirport("MUC", zones = List(zone))
            _    <- svc.createAirport(air)
            name <- svc.getCheckpointDisplayName("MUC", AirportCheckpoint.ArrivalsHall)
          } yield assertTrue(name == "T1 Arrivals Hall")
        },
        test("falls back to enum name when no zone matches the checkpoint type") {
          for {
            svc  <- ZIO.service[AirportConfigService]
            // Airport with no zones → no matching zone → fallback
            _    <- svc.createAirport(makeAirport("MUC"))
            name <- svc.getCheckpointDisplayName("MUC", AirportCheckpoint.ArrivalsHall)
          } yield assertTrue(name == AirportCheckpoint.ArrivalsHall.toString)
        },
        test("falls back to enum name when airport is unknown") {
          for {
            svc  <- ZIO.service[AirportConfigService]
            // Nothing seeded — unknown code
            name <- svc.getCheckpointDisplayName("XXX", AirportCheckpoint.Landed)
          } yield assertTrue(name == AirportCheckpoint.Landed.toString)
        }
      ).provide(freshServiceLayer),
      suite("deleteAirport (soft-delete)")(
        test("deleteAirport returns true for an existing active airport") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            result <- svc.deleteAirport("MUC")
          } yield assertTrue(result)
        },
        test("deleteAirport marks the airport as inactive (isActive = false)") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            _      <- svc.deleteAirport("MUC")
            // getAirport reads directly from the repository (bypasses active-only cache)
            result <- svc.getAirport("MUC")
          } yield assertTrue(
            result.isDefined,
            !result.get.isActive
          )
        },
        test("deleteAirport returns false for an already-inactive airport") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            _      <- svc.deleteAirport("MUC")
            second <- svc.deleteAirport("MUC") // already inactive
          } yield assertTrue(!second)
        },
        test("deleteAirport returns false for an unknown airport code") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            result <- svc.deleteAirport("ZZZ")
          } yield assertTrue(!result)
        }
      ).provide(freshServiceLayer),
      suite("zone CRUD")(
        test("createZone appends zone to the airport") {
          for {
            svc <- ZIO.service[AirportConfigService]
            _   <- svc.createAirport(makeAirport("MUC"))
            zone = makeZone("MUC", "terminal_exit", "T1 Exit")
            _   <- svc.createZone(zone)
            air <- svc.getAirport("MUC")
          } yield assertTrue(
            air.isDefined,
            air.get.zones.nonEmpty,
            air.get.zones.exists(_.displayName == "T1 Exit")
          )
        },
        test("deleteZone removes the zone from the airport") {
          for {
            svc  <- ZIO.service[AirportConfigService]
            _    <- svc.createAirport(makeAirport("MUC"))
            zone <- svc.createZone(makeZone("MUC", "arrivals_hall", "T1 Arrivals Hall"))
            _    <- svc.deleteZone(zone.id)
            air  <- svc.getAirport("MUC")
          } yield assertTrue(
            air.isDefined,
            air.get.zones.isEmpty
          )
        }
      ).provide(freshServiceLayer),

      // ─── Validation (moved from HTTP layer to service) ────────────────────────
      suite("input validation in service")(
        test("createAirport rejects latitude out of range") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            result <- svc.createAirport(makeAirport("BAD").copy(landingLat = 91.0)).exit
          } yield assertTrue(
            result.isFailure,
            result.causeOption.exists(_.squash match {
              case RideError.ValidationError(msg) => msg.contains("Latitude")
              case _                              => false
            })
          )
        },
        test("createAirport rejects longitude out of range") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            result <- svc.createAirport(makeAirport("BAD").copy(landingLon = 181.0)).exit
          } yield assertTrue(result.isFailure)
        },
        test("createAirport rejects non-positive radius") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            result <- svc.createAirport(makeAirport("BAD").copy(landingRadius = 0)).exit
          } yield assertTrue(result.isFailure)
        },
        test("createZone rejects invalid checkpoint type") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            zone    = makeZone("MUC", "INVALID_TYPE", "Bad Zone")
            result <- svc.createZone(zone).exit
          } yield assertTrue(
            result.isFailure,
            result.causeOption.exists(_.squash match {
              case RideError.ValidationError(msg) => msg.contains("Invalid checkpoint type")
              case _                              => false
            })
          )
        },
        test("createZone rejects out-of-range latitude") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            zone    = makeZone("MUC", "arrivals_hall", "Bad Lat Zone").copy(lat = -91.0)
            result <- svc.createZone(zone).exit
          } yield assertTrue(result.isFailure)
        },
        test("updateZone rejects invalid checkpoint type") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            zone   <- svc.createZone(makeZone("MUC", "arrivals_hall", "T1 Hall"))
            bad     = zone.copy(checkpointType = "NOT_VALID")
            result <- svc.updateZone(zone.id, bad).exit
          } yield assertTrue(result.isFailure)
        },

        // ─── updateAirport validation (mutation-kill for removing validateAirportCoords) ─

        test("updateAirport rejects latitude out of range") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            bad     = makeAirport("MUC").copy(landingLat = 91.0)
            result <- svc.updateAirport("MUC", bad).exit
          } yield assertTrue(
            result.isFailure,
            result.causeOption.exists(_.squash match {
              case RideError.ValidationError(msg) => msg.contains("Latitude")
              case _                              => false
            })
          )
        },
        test("updateAirport rejects longitude out of range") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            bad     = makeAirport("MUC").copy(landingLon = 181.0)
            result <- svc.updateAirport("MUC", bad).exit
          } yield assertTrue(
            result.isFailure,
            result.causeOption.exists(_.squash match {
              case RideError.ValidationError(msg) => msg.contains("Longitude")
              case _                              => false
            })
          )
        },
        test("updateAirport rejects non-positive landing radius") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            bad     = makeAirport("MUC").copy(landingRadius = 0)
            result <- svc.updateAirport("MUC", bad).exit
          } yield assertTrue(
            result.isFailure,
            result.causeOption.exists(_.squash match {
              case RideError.ValidationError(msg) => msg.toLowerCase.contains("radius")
              case _                              => false
            })
          )
        },

        // ─── updateZone validation (mutation-kill for removing validateZoneCoords) ─

        test("updateZone rejects latitude out of range") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            zone   <- svc.createZone(makeZone("MUC", "arrivals_hall", "T1 Hall"))
            bad     = zone.copy(lat = -91.0)
            result <- svc.updateZone(zone.id, bad).exit
          } yield assertTrue(
            result.isFailure,
            result.causeOption.exists(_.squash match {
              case RideError.ValidationError(msg) => msg.contains("Latitude")
              case _                              => false
            })
          )
        },
        test("updateZone rejects longitude out of range") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            zone   <- svc.createZone(makeZone("MUC", "arrivals_hall", "T1 Hall"))
            bad     = zone.copy(lon = 181.0)
            result <- svc.updateZone(zone.id, bad).exit
          } yield assertTrue(
            result.isFailure,
            result.causeOption.exists(_.squash match {
              case RideError.ValidationError(msg) => msg.contains("Longitude")
              case _                              => false
            })
          )
        },
        test("updateZone rejects non-positive radius") {
          for {
            svc    <- ZIO.service[AirportConfigService]
            _      <- svc.createAirport(makeAirport("MUC"))
            zone   <- svc.createZone(makeZone("MUC", "arrivals_hall", "T1 Hall"))
            bad     = zone.copy(radiusMeters = 0)
            result <- svc.updateZone(zone.id, bad).exit
          } yield assertTrue(
            result.isFailure,
            result.causeOption.exists(_.squash match {
              case RideError.ValidationError(msg) => msg.toLowerCase.contains("radius")
              case _                              => false
            })
          )
        }
      ).provide(freshServiceLayer)
    ) @@ TestAspect.sequential
}
