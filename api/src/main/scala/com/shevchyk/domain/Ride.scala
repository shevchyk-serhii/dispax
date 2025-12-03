package com.shevchyk.domain

import java.time.LocalDateTime
import zio.json.*

enum RideStatus derives JsonCodec:
  case Requested, Assigned, InProgress, Completed, Cancelled

case class Ride(
    id: Long,
    clientId: Int,
    creatorId: Int,
    driverId: Option[Int] = None,
    companyId: Int,
    scheduleDayId: Option[Long] = None,
    pickupDateTime: LocalDateTime,
    from: Location,
    to: Location,
    status: RideStatus = RideStatus.Requested
) derives JsonCodec
