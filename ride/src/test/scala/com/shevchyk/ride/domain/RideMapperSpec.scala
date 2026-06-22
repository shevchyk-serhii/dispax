package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import zio.*
import zio.test.*
import java.time.Instant
import java.util.UUID

object RideMapperSpec extends ZIOSpecDefault {

  private val companyId = CompanyId(UUID.randomUUID())
  private val clientId  = PersonId(UUID.randomUUID())
  private val pickup    = Location("Marienplatz 1, Munich", Some(48.137), Some(11.575))
  private val dropoff   = Location("Munich Airport", Some(48.353), Some(11.786))

  private def makeRequest(
      scheduledTime: Option[Instant] = None,
      vehicleClass: VehicleClass = VehicleClass.Default
  ) = CreateRideRequest(
    clientId = clientId,
    companyId = companyId,
    pickupLocation = pickup,
    dropoffLocation = dropoff,
    scheduledTime = scheduledTime,
    notes = Some("Test note"),
    specifics = None,
    specialRequirements = Some("Wheelchair"),
    vehicleClass = vehicleClass
  )

  def spec =
    suite("RideMapper")(
      test("maps clientId as both clientId and creatorId") {
        val ride = RideMapper.fromRequest(makeRequest())
        assertTrue(ride.clientId == clientId && ride.creatorId == clientId)
      },
      test("maps companyId correctly") {
        val ride = RideMapper.fromRequest(makeRequest())
        assertTrue(ride.companyId == companyId)
      },
      test("maps pickup and dropoff locations") {
        val ride = RideMapper.fromRequest(makeRequest())
        assertTrue(ride.pickupLocation == pickup && ride.dropoffLocation == dropoff)
      },
      test("uses scheduledTime as pickupDateTime when provided") {
        val scheduled = Instant.parse("2026-12-01T10:00:00Z")
        val ride      = RideMapper.fromRequest(makeRequest(scheduledTime = Some(scheduled)))
        assertTrue(ride.pickupDateTime == scheduled && ride.scheduledTime.contains(scheduled))
      },
      test("uses Instant.now() as pickupDateTime when scheduledTime is None") {
        val before = Instant.now().minusSeconds(1)
        val ride   = RideMapper.fromRequest(makeRequest(scheduledTime = None))
        val after  = Instant.now().plusSeconds(1)
        assertTrue(
          ride.scheduledTime.isEmpty && !ride.pickupDateTime.isBefore(before) && !ride.pickupDateTime.isAfter(after)
        )
      },
      test("maps notes and specialRequirements") {
        val ride = RideMapper.fromRequest(makeRequest())
        assertTrue(ride.notes.contains("Test note") && ride.specialRequirements.contains("Wheelchair"))
      },
      test("generates unique id for each call") {
        val r1 = RideMapper.fromRequest(makeRequest())
        val r2 = RideMapper.fromRequest(makeRequest())
        assertTrue(r1.id != r2.id)
      },
      test("defaults status to Requested") {
        val ride = RideMapper.fromRequest(makeRequest())
        assertTrue(ride.status == RideStatus.Requested)
      },
      test("maps specifics when provided") {
        val req  = makeRequest().copy(specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH123")))
        val ride = RideMapper.fromRequest(req)
        assertTrue(ride.specifics.contains(RideSpecifics.AirportTransfer("MUC", "LH123")))
      },
      // [HIGH] vehicleClass = request.vehicleClass — mutation to VehicleClass.Default survives the existing tests
      // because they all use the default.  This test uses Van (a non-default class) so the mutation is caught.
      test("preserves non-default vehicleClass from request") {
        val ride = RideMapper.fromRequest(makeRequest(vehicleClass = VehicleClass.Van))
        assertTrue(ride.vehicleClass == VehicleClass.Van)
      },
      // [MEDIUM] requestTime = Instant.now() — mutation to Instant.EPOCH survives existing tests.
      // We verify that requestTime is not the epoch and is within a 10-second window around now().
      test("requestTime is close to now, not epoch") {
        val before = Instant.now().minusSeconds(5)
        val ride   = RideMapper.fromRequest(makeRequest())
        val after  = Instant.now().plusSeconds(5)
        assertTrue(
          ride.requestTime != Instant.EPOCH,
          !ride.requestTime.isBefore(before),
          !ride.requestTime.isAfter(after)
        )
      }
    )
}
