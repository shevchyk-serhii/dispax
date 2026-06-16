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
      companyId: UUID
  ) extends WebSocketEvent

  final case class RideAssigned(
      rideId: UUID,
      driverId: UUID,
      clientId: UUID,
      companyId: UUID
  ) extends WebSocketEvent

  final case class RideCreated(
      rideId: UUID,
      clientId: UUID,
      companyId: UUID
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

  given JsonEncoder[WebSocketEvent] = DeriveJsonEncoder.gen[WebSocketEvent]
  given JsonDecoder[WebSocketEvent] = DeriveJsonDecoder.gen[WebSocketEvent]
