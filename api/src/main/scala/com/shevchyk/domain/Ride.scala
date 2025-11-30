package com.shevchyk.domain

import java.time.LocalDateTime

case class Ride(
    id: String,
    pickupDateTime: LocalDateTime,
    from: Location,
    to: Location
)
