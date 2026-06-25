package com.shevchyk.app.routes

import com.shevchyk.core.domain.WebSocketEvent
import zio.test.*

import java.util.UUID

/**
 * Guards the guest-tracking WebSocket projection: which events reach a guest, scoped to which ride, and — critically —
 * that the forwarded JSON carries NO PII (driver/client ids, companyId). Tests `eventRideId` (ride scoping) and
 * `guestPayload` (allowlist + sanitization) directly, no socket needed.
 */
object GuestWebSocketFilterSpec extends ZIOSpecDefault:

  private val rideId    = UUID.fromString("00000003-0000-0000-0000-000000000001")
  private val driverId  = UUID.fromString("00000003-0000-0000-0000-000000000002")
  private val clientId  = UUID.fromString("00000003-0000-0000-0000-000000000003")
  private val companyId = UUID.fromString("00000003-0000-0000-0000-000000000004")

  private val driverLoc = WebSocketEvent.LocationUpdated(Some(rideId), driverId, 48.1, 11.5, "driver", companyId)
  private val clientLoc = WebSocketEvent.LocationUpdated(Some(rideId), clientId, 48.2, 11.6, "client", companyId)
  private val status    = WebSocketEvent.RideStatusChanged(rideId, "InProgress", Some(driverId), clientId, companyId)
  private val approach  = WebSocketEvent.DriverApproaching(rideId, driverId, clientId, 480, "500m", companyId)
  private val chat      = WebSocketEvent.ChatMessageSent(rideId, driverId, "see you", companyId)

  def spec =
    suite("GuestWebSocketFilter")(
      suite("eventRideId")(
        test("extracts the ride id from guest-relevant events") {
          assertTrue(
            WebSocketRoutes.eventRideId(driverLoc).contains(rideId),
            WebSocketRoutes.eventRideId(status).contains(rideId),
            WebSocketRoutes.eventRideId(approach).contains(rideId)
          )
        }
      ),
      suite("guestPayload allowlist")(
        test("driver location is forwarded; client location is NOT") {
          assertTrue(
            WebSocketRoutes.guestPayload(driverLoc).isDefined,
            WebSocketRoutes.guestPayload(clientLoc).isEmpty // never expose client GPS
          )
        },
        test("status + approaching are forwarded; chat is NOT") {
          assertTrue(
            WebSocketRoutes.guestPayload(status).isDefined,
            WebSocketRoutes.guestPayload(approach).isDefined,
            WebSocketRoutes.guestPayload(chat).isEmpty
          )
        }
      ),
      suite("guestPayload sanitization (no PII)")(
        test("driver location payload omits driverId/userId and companyId") {
          val json = WebSocketRoutes.guestPayload(driverLoc).get
          assertTrue(
            json.contains("LocationUpdated"),
            json.contains(rideId.toString),
            json.contains("\"latitude\":48.1"),
            !json.contains(driverId.toString),
            !json.contains(companyId.toString)
          )
        },
        test("status payload omits driverId/clientId/companyId") {
          val json = WebSocketRoutes.guestPayload(status).get
          assertTrue(
            json.contains("\"newStatus\":\"InProgress\""),
            json.contains(rideId.toString),
            !json.contains(driverId.toString),
            !json.contains(clientId.toString),
            !json.contains(companyId.toString)
          )
        },
        test("approaching payload omits driverId/clientId/companyId but keeps distance/threshold") {
          val json = WebSocketRoutes.guestPayload(approach).get
          assertTrue(
            json.contains("\"distanceMeters\":480"),
            json.contains("\"threshold\":\"500m\""),
            !json.contains(driverId.toString),
            !json.contains(clientId.toString),
            !json.contains(companyId.toString)
          )
        }
      )
    )
