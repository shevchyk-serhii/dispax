package com.shevchyk.driver.application

import com.shevchyk.core.application.GeocodingService
import com.shevchyk.ride.domain.Ride
import com.shevchyk.ride.repository.ClientLocationRepository
import zio.*

/**
 * Computes a driver's ETA to a ride's destination.
 *
 * Single source of truth for ETA assembly, shared by the proximity HTTP endpoint and the predictive ETA monitor. Origin
 * is the driver's live location; the destination is the client's real-time location if known, otherwise the ride's
 * pickup coordinates (lazily geocoded from the address when missing).
 *
 * Uses the HERE Routing API when configured, falling back to a Haversine straight-line estimate (~50 km/h urban speed)
 * otherwise.
 */
trait EtaService:

  /**
   * ETA in minutes from the assigned driver's live location to the ride's destination. Returns `None` when there is no
   * driver location or no usable destination coordinates.
   */
  def etaForRide(ride: Ride): Task[Option[Int]]

object EtaService:

  // Fallback ETA estimate when the HERE API has no answer (~50 km/h urban speed).
  private[application] def estimateEtaMinutes(
      dLat: Double,
      dLng: Double,
      destLat: Double,
      destLng: Double
  ): Option[Int] =
    val R     = 6371000.0
    val dPhi  = math.toRadians(destLat - dLat)
    val dLam  = math.toRadians(destLng - dLng)
    val a     =
      math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(math.toRadians(dLat)) * math.cos(math.toRadians(destLat)) *
        math.sin(dLam / 2) * math.sin(dLam / 2)
    val distM = R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    val eta   = math.ceil(distM / (50000.0 / 60.0)).toInt // 50 km/h → minutes
    Some(math.max(1, eta))

  final class EtaServiceImpl(
      locationService: DriverLocationService,
      hereRouting: HereRoutingService,
      geocoding: GeocodingService,
      clientLocationRepository: ClientLocationRepository
  ) extends EtaService:

    override def etaForRide(ride: Ride): Task[Option[Int]] =
      ride.driverId match
        case None           => ZIO.none
        case Some(driverId) =>
          for {
            driverLoc <- locationService.getLocation(driverId)
            // Prefer the client's real-time location; fall back to the pickup coords.
            clientLoc <- clientLocationRepository.getLocation(ride.id).orElse(ZIO.none)
            // Lazily geocode the pickup address when its coordinates are missing.
            pickup    <-
              if ride.pickupLocation.latitude.isEmpty then
                geocoding.enrichLocation(ride.pickupLocation).orElse(ZIO.succeed(ride.pickupLocation))
              else ZIO.succeed(ride.pickupLocation)
            eta       <-
              // Resolve a real destination: client's live position first, else the pickup
              // coordinates. If neither is known we have no destination — return no ETA
              // rather than computing one against (0,0) ("Null Island").
              (for {
                dLat    <- driverLoc.map(_.latitude)
                dLng    <- driverLoc.map(_.longitude)
                destLat <- clientLoc.map(_.latitude).orElse(pickup.latitude)
                destLng <- clientLoc.map(_.longitude).orElse(pickup.longitude)
              } yield (dLat, dLng, destLat, destLng)) match
                case Some((dLat, dLng, destLat, destLng)) =>
                  hereRouting
                    .getEtaMinutes(dLat, dLng, destLat, destLng)
                    .map(_.orElse(estimateEtaMinutes(dLat, dLng, destLat, destLng)))
                case None                                 => ZIO.none
          } yield eta

  val layer: ZLayer[
    DriverLocationService & HereRoutingService & GeocodingService & ClientLocationRepository,
    Nothing,
    EtaService
  ] = ZLayer.fromFunction(EtaServiceImpl.apply)
