package com.shevchyk.app

import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.notification.application.FcmService
import com.shevchyk.notification.domain.PushNotification
import com.shevchyk.notification.repository.SentReminderRepository
import com.shevchyk.ride.repository.RideRepository
import zio.*

import java.time.format.DateTimeFormatter
import java.time.{Instant, ZoneOffset}

object ReminderScheduler:

  def start: ZIO[RideRepository & PersonRepository & FcmService & SentReminderRepository, Nothing, Unit] =
    val tick = checkAndSend.catchAll(e => ZIO.logError(s"ReminderScheduler error: $e"))
    ZIO.logInfo("ReminderScheduler started") *>
      tick.repeat(Schedule.fixed(1.minute)).forkDaemon.unit

  private def checkAndSend
      : ZIO[RideRepository & PersonRepository & FcmService & SentReminderRepository, Throwable, Unit] =
    for
      rideRepo   <- ZIO.service[RideRepository]
      personRepo <- ZIO.service[PersonRepository]
      fcm        <- ZIO.service[FcmService]
      sentRepo   <- ZIO.service[SentReminderRepository]
      now         = Instant.now()

      drivers     <- personRepo.findByRole(com.shevchyk.core.domain.PersonRole.Driver)
      minuteGroups = drivers.map(_.reminderMinutes).distinct

      _ <-
        ZIO.foreachDiscard(minuteGroups) { minutes =>
          val windowFrom = now.plusSeconds((minutes - 1) * 60L)
          val windowTo   = now.plusSeconds(minutes * 60L)
          for
            rides      <- rideRepo.findAssignedRidesInWindow(windowFrom, windowTo)
            driversById = drivers.filter(_.reminderMinutes == minutes).map(d => d.id -> d).toMap

            _ <-
              ZIO.foreachDiscard(rides) { ride =>
                ride.driverId match
                  case Some(driverId) if driversById.contains(driverId) =>
                    val driver = driversById(driverId)
                    sentRepo.isAlreadySent(ride.id, driverId).flatMap {
                      case true  => ZIO.unit
                      case false =>
                        val timeStr      = formatTime(ride.pickupDateTime)
                        val notification = PushNotification(
                          title = s"Ride in $minutes min",
                          body = s"At $timeStr (UTC): ${ride.pickupLocation.address} → ${ride.dropoffLocation.address}",
                          data = Map("rideId" -> ride.id.value.toString, "type" -> "ride_reminder")
                        )
                        fcm.sendToUser(driverId, notification) *>
                          sentRepo.markSent(ride.id, driverId) *>
                          ZIO.logInfo(s"Reminder sent to driver ${driver.name} for ride ${ride.id.value}")
                    }
                  case _                                                => ZIO.unit
              }
          yield ()
        }
    yield ()

  private def formatTime(instant: Instant): String = DateTimeFormatter
    .ofPattern("HH:mm")
    .format(instant.atZone(ZoneOffset.UTC))
