package com.shevchyk.core.domain

import zio.*
import java.time.Instant

trait DriverLocationProvider:
  def getDriverLocation(driverId: PersonId): Task[Option[(Double, Double, Instant)]]
