package com.shevchyk.ride.repository

import java.time.Instant
import java.util.UUID

import zio.*
import zio.test.*

import com.shevchyk.core.domain.{CompanyId, Location, PersonId, RideId}
import com.shevchyk.ride.domain.*

/**
 * Parity of `InMemoryRideRepository.update`/`updateIfStatus` with the production SQL SET clause (audit item).
 *
 * `PostgresRideRepository.rideSetClause` deliberately does NOT write `vehicle_class`, `flight_is_arrival` or
 * `airport_checkpoint`: the latter two have their own atomic writers (`updateCheckpoint` / `updateFlightStatus`) that a
 * stale in-memory ride object must not clobber, and `vehicle_class` has no update path at all. The in-memory double
 * used to replace the WHOLE ride, so a unit test could observe those fields "persisting" through `update()` while
 * production silently dropped them — the exact class of trap the `client_id` bug slipped through. The double must
 * mirror the SQL semantics.
 */
object InMemoryRideUpdateParitySpec extends ZIOSpecDefault:

  private val companyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  private val clientId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))

  private val baseRide = Ride(
    id = RideId(UUID.randomUUID()), // replaced by create()
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    status = RideStatus.Requested,
    pickupLocation = Location("A"),
    dropoffLocation = Location("B"),
    pickupDateTime = Instant.now().plusSeconds(3600),
    requestTime = Instant.now()
  )

  private def mutated(created: Ride): Ride = created.copy(
    notes = Some("persisted-note"),
    vehicleClass = VehicleClass.Van,
    flightIsArrival = Some(true),
    airportCheckpoint = Some(AirportCheckpoint.Landed)
  )

  def spec =
    suite("InMemoryRideRepository — update parity with rideSetClause")(
      test("update() persists SET-clause fields but NOT vehicleClass/flightIsArrival/airportCheckpoint") {
        for
          repo    <- ZIO.succeed(new InMemoryRideRepository)
          created <- repo.create(baseRide)
          _       <- repo.update(mutated(created))
          stored  <- repo.findById(created.id)
        yield assertTrue(
          stored.exists(_.notes.contains("persisted-note")),
          // Mirroring the SQL: these three fields must keep their stored values.
          stored.exists(_.vehicleClass == created.vehicleClass),
          stored.exists(_.flightIsArrival == created.flightIsArrival),
          stored.exists(_.airportCheckpoint.isEmpty)
        )
      },
      test("updateIfStatus() applies the same SET-clause semantics as update()") {
        for
          repo    <- ZIO.succeed(new InMemoryRideRepository)
          created <- repo.create(baseRide)
          applied <- repo.updateIfStatus(mutated(created), Set(RideStatus.Requested))
          stored  <- repo.findById(created.id)
        yield assertTrue(
          applied,
          stored.exists(_.notes.contains("persisted-note")),
          stored.exists(_.vehicleClass == created.vehicleClass),
          stored.exists(_.flightIsArrival == created.flightIsArrival),
          stored.exists(_.airportCheckpoint.isEmpty)
        )
      },
      test("a checkpoint written by updateCheckpoint survives a later stale update()") {
        // The real-world consequence of the parity: FlightStatusMonitor/guest checkpoints land via
        // the atomic writer; a dispatcher edit built from a stale ride object must not clobber them.
        for
          repo    <- ZIO.succeed(new InMemoryRideRepository)
          created <- repo.create(baseRide)
          _       <- repo.updateCheckpoint(created.id, AirportCheckpoint.ArrivalsHall)
          // Stale object: no checkpoint on it; an ordinary details edit follows.
          _       <- repo.update(created.copy(notes = Some("edited")))
          stored  <- repo.findById(created.id)
        yield assertTrue(
          stored.exists(_.notes.contains("edited")),
          stored.exists(_.airportCheckpoint.contains(AirportCheckpoint.ArrivalsHall))
        )
      }
    )
