package com.shevchyk.driver.domain

import com.shevchyk.core.domain.*
import java.time.Instant

enum DriverStatus:
  case Available, Busy, Offline

final case class DriverLocation(
    driverId: PersonId,
    latitude: Double,
    longitude: Double,
    updatedAt: Instant = Instant.now()
)

object DriverLocation:

  /**
   * Haversine formula — distance in meters between two GPS points
   */
  def distanceMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Int =
    val R    = 6371000.0 // Earth radius in meters
    val dLat = Math.toRadians(lat2 - lat1)
    val dLng = Math.toRadians(lng2 - lng1)
    val a    =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
        Math.sin(dLng / 2) * Math.sin(dLng / 2)
    val c    = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    (R * c).toInt
