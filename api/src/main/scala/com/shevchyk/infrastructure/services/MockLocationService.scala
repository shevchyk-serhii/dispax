package com.shevchyk.infrastructure.services

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.{LocationService, LocationError, RouteInfo}
import zio.*
import java.time.Duration


case class MockLocationService() extends LocationService:

  override def calculateRoute(from: Location, to: Location): IO[LocationError, RouteInfo] =
    val distance = Distance(calculateMockDistance(from, to))
    val duration = Duration.ofMinutes((distance.kilometers * 2).toLong) 
    ZIO.succeed(RouteInfo(distance, duration))

  override def getEstimatedDistance(from: Location, to: Location): IO[LocationError, Distance] = ZIO.succeed(
    Distance(calculateMockDistance(from, to))
  )

  override def geocodeAddress(address: String): IO[LocationError, Location] =
    
    val mockCoordinates =
      address.toLowerCase match
        case addr if addr.contains("munich center")                          => (48.1351, 11.5820)
        case addr if addr.contains("munich airport") || addr.contains("muc") => (48.3538, 11.7861)
        case addr if addr.contains("railway station")                        => (48.1412, 11.5581)
        case addr if addr.contains("downtown")                               => (48.1373, 11.5755)
        case _                                                               => (48.1351 + scala.util.Random.nextGaussian() * 0.1, 11.5820 + scala.util.Random.nextGaussian() * 0.1)

    ZIO.succeed(Location(address, Some(mockCoordinates._1), Some(mockCoordinates._2)))

  override def reverseGeocode(latitude: Double, longitude: Double): IO[LocationError, String] = ZIO.succeed(
    s"Address near coordinates ($latitude, $longitude)"
  )

  private def calculateMockDistance(from: Location, to: Location): Double =
    (from.latitude, from.longitude, to.latitude, to.longitude) match
      case (Some(lat1), Some(lon1), Some(lat2), Some(lon2)) => from.distanceTo(to)
      case _                                                =>
        
        if from.address.toLowerCase.contains("airport") || to.address.toLowerCase.contains("airport") then
          30.0 + scala.util.Random.nextDouble() * 20.0 
        else 5.0 + scala.util.Random.nextDouble() * 15.0 

object MockLocationService:
  val layer: ZLayer[Any, Nothing, LocationService] = ZLayer.succeed(MockLocationService())
