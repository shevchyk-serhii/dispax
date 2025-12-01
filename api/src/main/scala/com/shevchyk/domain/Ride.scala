package com.shevchyk.domain

import java.time.LocalDateTime
import zio.json.*

case class Ride(
    id: Long,
    pickupDateTime: LocalDateTime,
    from: Location,
    to: Location
) derives JsonCodec
