package com.shevchyk.notification.domain

import com.shevchyk.core.application.RideConfirmationData

object MessageTemplates:

  def rideConfirmationText(data: RideConfirmationData): String =
    val timeStr  = data.scheduledTime.map(t => s" scheduled for $t").getOrElse("")
    val priceStr = data.estimatedPrice.map(p => s" Estimated price: EUR $p.").getOrElse("")
    s"Dear ${data.clientName}, your ride from ${data.pickupAddress} to ${data.dropoffAddress}$timeStr has been confirmed.$priceStr Booking reference: ${data.bookingReference}"

  def driverAssignmentText(data: RideConfirmationData): String =
    val driverStr = data.driverName.getOrElse("a driver")
    s"Dear ${data.clientName}, $driverStr has been assigned to your ride from ${data.pickupAddress} to ${data.dropoffAddress}. Booking reference: ${data.bookingReference}"
