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
    status: RideStatus = RideStatus.Requested,
    flightNumber: Option[String] = None,
    flightTime: Option[LocalDateTime] = None,
    isAirportTransfer: Boolean = false,
    isArrival: Boolean = false,         
    gate: Option[String] = None,
    terminal: Option[String] = None,
    flightStatus: Option[String] = None 
) derives JsonCodec
