package com.shevchyk.infrastructure.services

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.{LocationService, LocationError, RouteInfo}
import zio.*
import java.time.Duration

case class StubLocationService() extends LocationService:

  def calculateRoute(from: Location, to: Location): IO[LocationError, RouteInfo] =
    val distance          = calculateStraightLineDistance(from, to)
    val estimatedDuration = Duration.ofMinutes((distance.kilometers * 2).toLong) // 2 minutes per km
    ZIO.succeed(RouteInfo(distance, estimatedDuration))

  def getEstimatedDistance(from: Location, to: Location): IO[LocationError, Distance] = ZIO.succeed(
    calculateStraightLineDistance(from, to)
  )

  def geocodeAddress(address: String): IO[LocationError, Location] =
    // Simple geocoding stub - Munich area coordinates
    if address.toLowerCase.contains("airport") then
      ZIO.succeed(
        Location(
          address = address,
          latitude = Some(48.3538),
          longitude = Some(11.7861)
        )
      )
    else
      ZIO.succeed(
        Location(
          address = address,
          latitude = Some(48.1351),
          longitude = Some(11.5820)
        )
      )

  def reverseGeocode(latitude: Double, longitude: Double): IO[LocationError, String] = ZIO.succeed(
    s"Address at $latitude, $longitude"
  )

  private def calculateStraightLineDistance(from: Location, to: Location): Distance =
    (from.latitude, from.longitude, to.latitude, to.longitude) match
      case (Some(lat1), Some(lon1), Some(lat2), Some(lon2)) =>
        val R           = 6371.0 // Earth's radius in km
        val lat1Rad     = math.toRadians(lat1)
        val lat2Rad     = math.toRadians(lat2)
        val deltaLatRad = math.toRadians(lat2 - lat1)
        val deltaLonRad = math.toRadians(lon2 - lon1)

        val a =
          math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
            math.cos(lat1Rad) * math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2)

        val c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        Distance(R * c)
      case _                                                => Distance(10.0) // Default distance if coordinates are missing

object StubLocationService:
  val layer: ULayer[LocationService] = ZLayer.succeed(StubLocationService())
