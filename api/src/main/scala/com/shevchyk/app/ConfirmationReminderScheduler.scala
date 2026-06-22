package com.shevchyk.app

import com.shevchyk.notification.application.FcmService
import com.shevchyk.notification.domain.PushNotification
import com.shevchyk.core.repository.SentConfirmationRequestRepository
import com.shevchyk.ride.repository.RideRepository
import zio.*

import java.time.{Instant, LocalDate, LocalTime, ZoneId}

/**
 * Every morning (in the Europe/Berlin timezone) sends a confirmation-request push to the assigned driver of each ride
 * scheduled for the current day that is still in the `Assigned` state. Uses `sent_confirmation_requests` for
 * deduplication so each driver/ride pair is only notified once per assignment cycle. Early or late rides (pickup before
 * the morning window has run) are caught by the catchup check that runs on every tick.
 */
object ConfirmationReminderScheduler:

  // Default morning hour (Europe/Berlin, local time) at which the push is sent.
  private val MorningHour: Int = 7
  private val Timezone: ZoneId = ZoneId.of("Europe/Berlin")

  def start: ZIO[RideRepository & FcmService & SentConfirmationRequestRepository, Nothing, Unit] =
    ZIO.logInfo("ConfirmationReminderScheduler started") *>
      tick
        .catchAll(e => ZIO.logError(s"ConfirmationReminderScheduler error: $e"))
        .repeat(Schedule.fixed(1.minute))
        .forkDaemon
        .unit

  /**
   * Single tick — exposed for deterministic unit testing.
   */
  def tick: ZIO[RideRepository & FcmService & SentConfirmationRequestRepository, Throwable, Unit] =
    for {
      rideRepo        <- ZIO.service[RideRepository]
      fcm             <- ZIO.service[FcmService]
      sentRepo        <- ZIO.service[SentConfirmationRequestRepository]
      now              = Instant.now()
      zone             = Timezone
      today            = LocalDate.ofInstant(now, zone)
      dayStart         = today.atStartOfDay(zone).toInstant
      dayEnd           = today.plusDays(1).atStartOfDay(zone).toInstant
      // Morning threshold: the local time at which we start sending.
      morningThreshold = today.atTime(LocalTime.of(MorningHour, 0)).atZone(zone).toInstant
      // Send if we are at or past the morning window, OR if the ride starts before the morning
      // window (early/night rides need a confirmation request as soon as possible).
      pastMorning      = !now.isBefore(morningThreshold)
      rides           <- rideRepo.findRidesNeedingConfirmation(dayStart, dayEnd)
      _               <-
        ZIO.foreachParDiscard(rides) { ride =>
          ride.driverId match
            case None           => ZIO.unit
            case Some(driverId) =>
              // Send for early rides (pickup before morning window) on any tick;
              // send for other rides only once the morning window has opened.
              val isEarlyRide = ride.pickupDateTime.isBefore(morningThreshold)
              val shouldSend  = isEarlyRide || pastMorning
              ZIO
                .when(shouldSend) {
                  sentRepo.isAlreadySent(ride.id, driverId).flatMap {
                    case true  => ZIO.unit
                    case false =>
                      val notification = PushNotification(
                        title = "Confirm your ride",
                        body = s"Please confirm or reject the ride at ${ride.pickupLocation.address}.",
                        data = Map(
                          "rideId" -> ride.id.value.toString,
                          "type"   -> "ride_confirmation_request"
                        )
                      )
                      fcm.sendToUser(driverId, notification) *>
                        sentRepo.markSent(ride.id, driverId) *>
                        ZIO.logInfo(
                          s"Confirmation request sent for ride ${ride.id.value} to driver ${driverId.value}"
                        )
                  }
                }
                .unit
        }
    } yield ()
