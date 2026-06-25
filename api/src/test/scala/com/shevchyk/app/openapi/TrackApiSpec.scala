package com.shevchyk.app.openapi

import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.ride.application.service.LocationWithTimestamp
import com.shevchyk.ride.domain.{Ride, RideStatus}
import sttp.tapir.server.ziohttp.ZioHttpInterpreter
import sttp.tapir.ztapir.*
import zio.*
import zio.http.*
import zio.json.*
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Guards the public guest DTO projection: the JSON a guest receives must carry only status/route/driver-coords/eta — NO
 * clientId, driverId, price, or notes. Tests `TrackApi.toPublicDto` and the DTO's JSON encoding directly.
 */
object TrackApiSpec extends ZIOSpecDefault:

  private val driverId = PersonId(UUID.fromString("000000DD-0000-0000-0000-000000000001"))
  private val clientId = PersonId(UUID.fromString("000000CC-0000-0000-0000-000000000001"))

  private val ride = Ride(
    id = RideId(UUID.fromString("000000AA-AAAA-0000-0000-000000000001")),
    clientId = clientId,
    creatorId = clientId,
    companyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001")),
    driverId = Some(driverId),
    status = RideStatus.InProgress,
    pickupLocation = Location("Marienplatz", Some(48.137), Some(11.575)),
    dropoffLocation = Location("Airport", Some(48.353), Some(11.786)),
    pickupDateTime = Instant.now().plusSeconds(3600),
    estimatedPrice = Some(BigDecimal(49.90)),
    notes = Some("VIP client, call on arrival")
  )

  def spec =
    suite("TrackApiSpec")(
      test("toPublicDto exposes status, route, driver location, eta and driverAssigned") {
        val dto = TrackApi.toPublicDto(
          ride,
          Some(LocationWithTimestamp(48.14, 11.58, Instant.parse("2026-06-25T10:00:00Z"))),
          Some(7)
        )
        assertTrue(
          dto.status == "InProgress",
          dto.pickup.address == "Marienplatz",
          dto.dropoff.address == "Airport",
          dto.driverLocation.exists(_.latitude == 48.14),
          dto.etaMinutes.contains(7),
          dto.driverAssigned
        )
      },
      test("toPublicDto driverAssigned is false when the ride has no driver") {
        val dto = TrackApi.toPublicDto(ride.copy(driverId = None), None, None)
        assertTrue(!dto.driverAssigned, dto.driverLocation.isEmpty)
      },
      test("the encoded JSON leaks NO PII (clientId/driverId/price/notes)") {
        val json =
          TrackApi
            .toPublicDto(ride, Some(LocationWithTimestamp(48.14, 11.58, Instant.now())), Some(7))
            .toJson
        assertTrue(
          !json.contains(clientId.value.toString),
          !json.contains(driverId.value.toString),
          !json.contains("49.9"),       // price must not appear
          !json.contains("VIP client"), // notes must not appear
          !json.contains("clientId"),
          !json.contains("driverId")
        )
      },
      test("GET /api/track/{token} maps a failure to 404, not 400 (no existence leak, page treats 404 as expired)") {
        // Interpret the real endpoint description with a logic that always fails — the status comes from the
        // endpoint's errorOut declaration. A regression to the default public 400 would turn this red.
        val failing = TrackApi.getTrackedRideEndpoint.zServerLogic[Any](_ =>
          ZIO.fail(ApiError("Tracking link not found or expired"))
        )
        val routes  = ZioHttpInterpreter().toHttp(List(failing))
        for {
          resp <- routes.runZIO(Request.get(URL.decode("/api/track/whatever").toOption.get))
        } yield assertTrue(resp.status == Status.NotFound)
      }
    )
