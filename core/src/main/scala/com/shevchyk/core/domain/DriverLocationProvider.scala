package com.shevchyk.core.domain

import zio.*
import java.time.Instant
import java.util.UUID

trait DriverLocationProvider:
  def getDriverLocation(driverId: PersonId): Task[Option[(Double, Double, Instant)]]
