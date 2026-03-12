package com.shevchyk.core.application

import zio.*

/**
 * Ride confirmation data for email/SMS notifications
 */
final case class RideConfirmationData(
    rideId: String,
    clientName: String,
    pickupAddress: String,
    dropoffAddress: String,
    scheduledTime: Option[java.time.Instant] = None,
    driverName: Option[String] = None,
    estimatedPrice: Option[BigDecimal] = None
)

/**
 * Service for sending email/SMS notifications. Implementations live in the notification module.
 */
trait EmailSmsService:
  def sendRideConfirmation(data: RideConfirmationData): Task[Unit]
  def sendDriverAssignment(data: RideConfirmationData): Task[Unit]
