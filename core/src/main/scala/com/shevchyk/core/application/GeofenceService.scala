package com.shevchyk.core.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.GeofenceRepository
import zio.*
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

trait GeofenceService:
  def checkDriverLocation(driverId: PersonId, companyId: CompanyId, lat: Double, lng: Double): UIO[List[GeofenceAlert]]
  def checkClientProximity(driverId: PersonId, lat: Double, lng: Double, activeRides: List[ActiveRideInfo]): UIO[Unit]

/**
 * Minimal ride info needed by GeofenceService to avoid depending on ride module
 */
final case class ActiveRideInfo(
    rideId: UUID,
    clientId: UUID,
    pickupLatitude: Option[Double],
    pickupLongitude: Option[Double],
    companyId: UUID
)

class GeofenceServiceImpl(
    repository: GeofenceRepository,
    eventHub: EventHub,
    driverGeofenceState: Ref[Map[UUID, Set[UUID]]],      // driverId -> set of geofenceIds currently inside
    proximityThresholdState: Ref[Map[UUID, Set[String]]] // rideId -> set of triggered thresholds
) extends GeofenceService:

  private val EARTH_RADIUS_METERS = 6371000.0

  private def haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Int =
    val dLat = Math.toRadians(lat2 - lat1)
    val dLng = Math.toRadians(lng2 - lng1)
    val a    =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
        Math.sin(dLng / 2) * Math.sin(dLng / 2)
    val c    = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    (EARTH_RADIUS_METERS * c).toInt

  override def checkDriverLocation(
      driverId: PersonId,
      companyId: CompanyId,
      lat: Double,
      lng: Double
  ): UIO[List[GeofenceAlert]] =
    (for {
      activeGeofences <- repository.findActiveByCompanyId(companyId)
      nowInsideIds     =
        activeGeofences
          .filter { g =>
            haversineDistance(lat, lng, g.centerLatitude, g.centerLongitude) < g.radiusMeters
          }
          .map(_.id.value)
          .toSet

      previousState <- driverGeofenceState.get
      previousIds    = previousState.getOrElse(driverId.value, Set.empty)

      entered = nowInsideIds -- previousIds
      exited  = previousIds -- nowInsideIds

      geofenceMap = activeGeofences.map(g => g.id.value -> g).toMap

      entryAlerts <-
        ZIO.foreach(entered.toList) { gfId =>
          geofenceMap.get(gfId) match
            case Some(g) if g.notifyOnEntry =>
              val alert = GeofenceAlert(
                id = UuidCreator.getTimeOrderedEpoch(),
                geofenceId = GeofenceId(gfId),
                driverId = driverId,
                companyId = companyId,
                alertType = "entry",
                geofenceName = g.name,
                latitude = lat,
                longitude = lng
              )
              repository.saveAlert(alert).ignore *>
                eventHub
                  .publish(
                    WebSocketEvent.GeofenceTriggered(
                      geofenceId = gfId,
                      geofenceName = g.name,
                      driverId = driverId.value,
                      alertType = "entry",
                      latitude = lat,
                      longitude = lng,
                      companyId = companyId.value
                    )
                  )
                  .ignore
                  .as(Some(alert))
            case _                          => ZIO.succeed(None)
        }

      exitAlerts <-
        ZIO.foreach(exited.toList) { gfId =>
          geofenceMap.get(gfId) match
            case Some(g) if g.notifyOnExit =>
              val alert = GeofenceAlert(
                id = UuidCreator.getTimeOrderedEpoch(),
                geofenceId = GeofenceId(gfId),
                driverId = driverId,
                companyId = companyId,
                alertType = "exit",
                geofenceName = g.name,
                latitude = lat,
                longitude = lng
              )
              repository.saveAlert(alert).ignore *>
                eventHub
                  .publish(
                    WebSocketEvent.GeofenceTriggered(
                      geofenceId = gfId,
                      geofenceName = g.name,
                      driverId = driverId.value,
                      alertType = "exit",
                      latitude = lat,
                      longitude = lng,
                      companyId = companyId.value
                    )
                  )
                  .ignore
                  .as(Some(alert))
            case _                         => ZIO.succeed(None)
        }

      _ <- driverGeofenceState.update(_.updated(driverId.value, nowInsideIds))

      allAlerts = (entryAlerts ++ exitAlerts).flatten
    } yield allAlerts).catchAll { e =>
      ZIO.logWarning(s"Geofence check failed: ${Option(e.getMessage).getOrElse(e.toString)}").as(List.empty)
    }

  override def checkClientProximity(
      driverId: PersonId,
      lat: Double,
      lng: Double,
      activeRides: List[ActiveRideInfo]
  ): UIO[Unit] =
    ZIO.foreachDiscard(activeRides) { ride =>
      val distanceOpt =
        for {
          pickLat <- ride.pickupLatitude
          pickLng <- ride.pickupLongitude
        } yield haversineDistance(lat, lng, pickLat, pickLng)

      distanceOpt match
        case Some(distance) =>
          val thresholds = List(
            (2000, "2km"),
            (500, "500m"),
            (100, "100m")
          )
          ZIO.foreachDiscard(thresholds) { case (meters, label) =>
            ZIO.when(distance <= meters) {
              for {
                state    <- proximityThresholdState.get
                triggered = state.getOrElse(ride.rideId, Set.empty)
                _        <-
                  ZIO.when(!triggered.contains(label)) {
                    proximityThresholdState.update(_.updated(ride.rideId, triggered + label)) *>
                      eventHub
                        .publish(
                          WebSocketEvent.DriverApproaching(
                            rideId = ride.rideId,
                            driverId = driverId.value,
                            clientId = ride.clientId,
                            distanceMeters = distance,
                            threshold = label,
                            companyId = ride.companyId
                          )
                        )
                        .ignore
                  }
              } yield ()
            }
          }
        case None           => ZIO.unit
    }

object GeofenceService:

  val layer: ZLayer[GeofenceRepository & EventHub, Nothing, GeofenceService] = ZLayer.fromZIO {
    for {
      repo     <- ZIO.service[GeofenceRepository]
      eventHub <- ZIO.service[EventHub]
      gfState  <- Ref.make(Map.empty[UUID, Set[UUID]])
      pxState  <- Ref.make(Map.empty[UUID, Set[String]])
    } yield GeofenceServiceImpl(repo, eventHub, gfState, pxState)
  }
