package com.shevchyk.notification.domain

import com.shevchyk.core.application.{InvoiceEmailData, RideConfirmationData}

object MessageTemplates:

  def invoiceEmailSubject(data: InvoiceEmailData): String =
    if data.isReminder then s"Zahlungserinnerung: Rechnung ${data.invoiceNumber}"
    else s"Ihre Rechnung ${data.invoiceNumber}"

  def invoiceEmailBody(data: InvoiceEmailData): String =
    val amountStr = s"${data.totalAmount} ${data.currency}"
    val dueStr    = data.dueDate.map(d => s" Zahlbar bis zum $d.").getOrElse("")
    if data.isReminder then s"""Sehr geehrte Damen und Herren von ${data.toName},
                               |
                               |unsere Rechnung ${data.invoiceNumber} über $amountStr ist noch offen.$dueStr
                               |Wir bitten Sie, den Betrag zeitnah zu begleichen. Die Rechnung finden Sie im Anhang.
                               |
                               |Mit freundlichen Grüßen""".stripMargin
    else s"""Sehr geehrte Damen und Herren von ${data.toName},
            |
            |anbei erhalten Sie unsere Rechnung ${data.invoiceNumber} über $amountStr.$dueStr
            |
            |Mit freundlichen Grüßen""".stripMargin

  def rideConfirmationText(data: RideConfirmationData): String =
    val timeStr  = data.scheduledTime.map(t => s" scheduled for $t").getOrElse("")
    val priceStr = data.estimatedPrice.map(p => s" Estimated price: EUR $p.").getOrElse("")
    s"Dear ${data.clientName}, your ride from ${data.pickupAddress} to ${data.dropoffAddress}$timeStr has been confirmed.$priceStr Ride ID: ${data.rideId}"

  def driverAssignmentText(data: RideConfirmationData): String =
    val driverStr = data.driverName.getOrElse("a driver")
    s"Dear ${data.clientName}, $driverStr has been assigned to your ride from ${data.pickupAddress} to ${data.dropoffAddress}. Ride ID: ${data.rideId}"
