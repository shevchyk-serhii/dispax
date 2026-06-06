package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class RideRatingId(value: UUID) derives JsonCodec

object RideRatingId:
  def generate(): RideRatingId = RideRatingId(UuidCreator.getTimeOrderedEpoch())

final case class RideRating(
    id: RideRatingId,
    rideId: RideId,
    clientId: PersonId,
    driverId: PersonId,
    companyId: CompanyId,
    rating: Int,
    comment: Option[String] = None,
    createdAt: Instant = Instant.now()
) derives JsonCodec

final case class CreateRatingRequest(
    // Optional: the ride id is taken from the URL path, so clients only send
    // `rating` and `comment`. Keeping it optional avoids a JSON-decode failure.
    rideId: Option[String] = None,
    rating: Int,
    comment: Option[String] = None
) derives JsonCodec
