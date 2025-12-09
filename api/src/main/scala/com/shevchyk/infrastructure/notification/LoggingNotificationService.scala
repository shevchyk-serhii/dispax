package com.shevchyk.infrastructure.notification

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.{NotificationService, NotificationError}
import zio.*


case class LoggingNotificationService() extends NotificationService:

  override def notifyDriver(
      driverId: PersonId,
      message: String,
      rideId: Option[RideId] = None
  ): IO[NotificationError, Unit] = ZIO.logInfo(
    s"[DRIVER NOTIFICATION] Driver ${driverId.value}: $message ${rideId.map(id => s"(Ride: ${id.value})").getOrElse("")}"
  )

  override def notifyClient(
      clientId: PersonId,
      message: String,
      rideId: Option[RideId] = None
  ): IO[NotificationError, Unit] = ZIO.logInfo(
    s"[CLIENT NOTIFICATION] Client ${clientId.value}: $message ${rideId.map(id => s"(Ride: ${id.value})").getOrElse("")}"
  )

  override def notifyCompany(
      companyId: CompanyId,
      message: String,
      rideId: Option[RideId] = None
  ): IO[NotificationError, Unit] = ZIO.logInfo(
    s"[COMPANY NOTIFICATION] Company ${companyId.value}: $message ${rideId.map(id => s"(Ride: ${id.value})").getOrElse("")}"
  )

  override def sendSMSNotification(phoneNumber: String, message: String): IO[NotificationError, Unit] = ZIO.logInfo(
    s"[SMS] To $phoneNumber: $message"
  )

  override def sendEmailNotification(email: String, subject: String, message: String): IO[NotificationError, Unit] = ZIO
    .logInfo(s"[EMAIL] To $email, Subject: $subject, Message: $message")

object LoggingNotificationService:
  val layer: ZLayer[Any, Nothing, NotificationService] = ZLayer.succeed(LoggingNotificationService())
