package com.shevchyk.notification.application

import com.shevchyk.core.application.{EmailSmsService, RideConfirmationData}
import com.shevchyk.notification.domain.MessageTemplates
import zio.*

class LoggingEmailSmsService extends EmailSmsService:

  override def sendRideConfirmation(data: RideConfirmationData): Task[Unit] =
    val message = MessageTemplates.rideConfirmationText(data)
    ZIO.logInfo(s"[EMAIL/SMS PLACEHOLDER] Ride Confirmation: $message")

  override def sendDriverAssignment(data: RideConfirmationData): Task[Unit] =
    val message = MessageTemplates.driverAssignmentText(data)
    ZIO.logInfo(s"[EMAIL/SMS PLACEHOLDER] Driver Assignment: $message")

object LoggingEmailSmsService:
  val layer: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new LoggingEmailSmsService)
