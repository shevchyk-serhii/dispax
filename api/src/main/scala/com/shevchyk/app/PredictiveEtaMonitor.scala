package com.shevchyk.app

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.WebSocketEvent
import com.shevchyk.driver.application.EtaService
import com.shevchyk.notification.repository.EtaAlertRepository
import com.shevchyk.ride.domain.Ride
import com.shevchyk.ride.repository.RideRepository
import zio.*

import java.time.{Duration, Instant}

/**
 * Predictive ETA monitor — the "punctuality guarantee" background job.
 *
 * Periodically scans assigned rides whose pickup is approaching, computes the driver's live ETA, and — when the driver
 * is at risk of missing the pickup on time — emits a `WebSocketEvent.EtaAtRisk` so dispatchers are alerted *before* the
 * client notices. Mirrors the structure of [[ReminderScheduler]].
 *
 * Alerts are deduplicated per (ride, driver) via [[EtaAlertRepository]], so a sustained at-risk situation produces a
 * single alert rather than one per tick.
 */
object PredictiveEtaMonitor:

  // How far ahead to look for pickups worth monitoring.
  private val LookAheadMinutes     = 45L
  // Alert when the slack (minutes spare before pickup) drops below this.
  private val RiskThresholdMinutes = 5L

  type Env = RideRepository & EtaService & EtaAlertRepository & EventHub

  def start: ZIO[Env, Nothing, Unit] =
    // Bound concurrency of the parallel ETA evaluations (each hits the external HERE API) so a
    // busy window doesn't flood the routing provider with simultaneous requests.
    val safeTick = tick.withParallelism(8).catchAll(e => ZIO.logError(s"PredictiveEtaMonitor error: $e"))
    ZIO.logInfo("PredictiveEtaMonitor started") *>
      safeTick.repeat(Schedule.fixed(1.minute)).forkDaemon.unit

  /**
   * A single monitoring pass. Exposed for deterministic tests.
   */
  private[app] def tick: ZIO[Env, Throwable, Unit] =
    for
      rideRepo  <- ZIO.service[RideRepository]
      etaSvc    <- ZIO.service[EtaService]
      alertRepo <- ZIO.service[EtaAlertRepository]
      eventHub  <- ZIO.service[EventHub]
      now        = Instant.now()
      windowTo   = now.plusSeconds(LookAheadMinutes * 60L)
      rides     <- rideRepo.findAssignedRidesInWindow(now, windowTo)
      _         <- ZIO.foreachParDiscard(rides)(ride => evaluate(ride, now, etaSvc, alertRepo, eventHub))
    yield ()

  private def evaluate(
      ride: Ride,
      now: Instant,
      etaSvc: EtaService,
      alertRepo: EtaAlertRepository,
      eventHub: EventHub
  ): ZIO[Any, Throwable, Unit] =
    ride.driverId match
      case None           => ZIO.unit
      case Some(driverId) =>
        val pickup             = ride.scheduledTime.getOrElse(ride.pickupDateTime)
        val minutesUntilPickup = Duration.between(now, pickup).toMinutes
        etaSvc.etaForRide(ride).flatMap {
          case None      => ZIO.unit // no driver location / coords → cannot assess
          case Some(eta) =>
            val slack = minutesUntilPickup - eta.toLong
            if slack >= RiskThresholdMinutes then ZIO.unit
            else
              // Atomic claim: only the tick that actually inserted the (ride, driver) row publishes the alert,
              // so two concurrent ticks can't both fire for the same at-risk ride.
              alertRepo.markAlertedIfNew(ride.id, driverId).flatMap {
                case false => ZIO.unit
                case true  =>
                  val event = WebSocketEvent.EtaAtRisk(
                    rideId = ride.id.value,
                    driverId = driverId.value,
                    clientId = ride.clientId.value,
                    etaMinutes = eta,
                    minutesUntilPickup = minutesUntilPickup.toInt,
                    slackMinutes = slack.toInt,
                    companyId = ride.companyId.value
                  )
                  eventHub.publish(event) *>
                    ZIO.logInfo(
                      s"ETA at risk for ride ${ride.id.value}: eta=${eta}m, until pickup=${minutesUntilPickup}m, slack=${slack}m"
                    )
              }
        }
