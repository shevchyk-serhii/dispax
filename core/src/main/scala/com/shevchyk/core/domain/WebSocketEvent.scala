package com.shevchyk.core.domain

import zio.json.*
import java.util.UUID

sealed trait WebSocketEvent:
  def companyId: UUID

object WebSocketEvent:

  final case class RideStatusChanged(
      rideId: UUID,
      newStatus: String,
      driverId: Option[UUID],
      clientId: UUID,
      companyId: UUID,
      cancellationReason: Option[String] = None
  ) extends WebSocketEvent

  final case class RideDetailsUpdated(
      rideId: UUID,
      driverId: Option[UUID],
      clientId: UUID,
      companyId: UUID,
      // Set when this update reassigned the ride to a different client; carries the client
      // the ride was taken away from so consumers can notify/refresh that person.
      previousClientId: Option[UUID] = None
  ) extends WebSocketEvent

  final case class RideAssigned(
      rideId: UUID,
      driverId: UUID,
      clientId: UUID,
      companyId: UUID,
      // The ride fare (€) carried so notifications can show the amount without a
      // repository lookup. None when the ride has no price set.
      price: Option[BigDecimal] = None,
      // Set when this assignment displaced another driver (reassignment): carries the
      // driver the ride was taken away from so consumers can notify that person —
      // otherwise a backgrounded driver keeps heading to a pickup that is no longer theirs.
      previousDriverId: Option[UUID] = None
  ) extends WebSocketEvent

  final case class RideCreated(
      rideId: UUID,
      clientId: UUID,
      companyId: UUID,
      // The ride fare (€) carried so notifications can show the amount. None when
      // the ride has no price set.
      price: Option[BigDecimal] = None
  ) extends WebSocketEvent

  final case class LocationUpdated(
      rideId: Option[UUID],
      userId: UUID,
      latitude: Double,
      longitude: Double,
      locationType: String, // "driver" or "client"
      companyId: UUID
  ) extends WebSocketEvent

  final case class ChatMessageSent(
      rideId: UUID,
      senderId: UUID,
      message: String,
      companyId: UUID
  ) extends WebSocketEvent

  final case class GeofenceTriggered(
      geofenceId: UUID,
      geofenceName: String,
      driverId: UUID,
      alertType: String, // "entry" or "exit"
      latitude: Double,
      longitude: Double,
      companyId: UUID
  ) extends WebSocketEvent

  final case class DriverApproaching(
      rideId: UUID,
      driverId: UUID,
      clientId: UUID,
      distanceMeters: Int,
      threshold: String, // "2km", "500m", "100m"
      companyId: UUID
  ) extends WebSocketEvent

  /**
   * The assigned driver is at risk of missing the pickup on time. Emitted by the predictive ETA monitor to alert the
   * company's dispatchers. `slackMinutes` = minutesUntilPickup - etaMinutes (negative = already late).
   */
  final case class EtaAtRisk(
      rideId: UUID,
      driverId: UUID,
      clientId: UUID,
      etaMinutes: Int,
      minutesUntilPickup: Int,
      slackMinutes: Int,
      companyId: UUID
  ) extends WebSocketEvent

  final case class AirportCheckpointReached(
      rideId: UUID,
      driverId: UUID,
      clientId: UUID,
      checkpointType: String, // "landed" | "arrivals_hall" | "terminal_exit"
      checkpointName: String, // human-readable display name
      companyId: UUID
  ) extends WebSocketEvent

  /**
   * The assigned driver has confirmed the ride. All dispatchers of the company are notified. The dispatcher UI should
   * re-colour the ride row from red (unconfirmed) to green.
   */
  final case class RideConfirmed(
      rideId: UUID,
      driverId: UUID,
      clientId: UUID,
      companyId: UUID
  ) extends WebSocketEvent

  /**
   * The assigned driver has rejected the ride (with a reason). The ride reverts to Requested status and the driver is
   * unassigned. All dispatchers of the company are notified so they can react in time.
   */
  final case class RideRejected(
      rideId: UUID,
      driverId: UUID,
      clientId: UUID,
      reason: String,
      companyId: UUID
  ) extends WebSocketEvent

  /**
   * Live flight data for an airport-transfer ride changed (status/gate/terminal/estimated time). Emitted by the
   * background flight monitor when it detects a change versus what was last persisted, so dispatchers and the client
   * see the new gate/status without a manual refresh. `status` is the canonical wire string (FlightStatus.toWire);
   * `estimatedTime` is the ISO instant of the latest known time, when available.
   */
  final case class FlightStatusUpdated(
      rideId: UUID,
      clientId: UUID,
      companyId: UUID,
      flightNumber: String,
      status: String,
      gate: Option[String] = None,
      terminal: Option[String] = None,
      estimatedTime: Option[String] = None,
      // Origin take-off instant (arrivals), so the card's en-route airplane appears live without a reload.
      departureTime: Option[String] = None
  ) extends WebSocketEvent

  given JsonEncoder[WebSocketEvent] = DeriveJsonEncoder.gen[WebSocketEvent]
  given JsonDecoder[WebSocketEvent] = DeriveJsonDecoder.gen[WebSocketEvent]
