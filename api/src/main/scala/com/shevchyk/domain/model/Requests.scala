package com.shevchyk.domain.model

import java.time.LocalDateTime
import zio.json.JsonCodec

case class CreateRideRequest(
    clientId: PersonId,
    creatorId: PersonId,
    from: Location,
    to: Location,
    pickupDateTime: LocalDateTime,
    flightNumber: Option[String] = None
) derives JsonCodec
