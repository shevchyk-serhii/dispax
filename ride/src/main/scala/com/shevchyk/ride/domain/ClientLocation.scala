package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import java.time.Instant

final case class ClientLocation(
    rideId: RideId,
    clientId: PersonId,
    latitude: Double,
    longitude: Double,
    updatedAt: Instant = Instant.now()
)
