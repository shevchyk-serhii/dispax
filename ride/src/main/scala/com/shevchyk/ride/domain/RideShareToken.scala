package com.shevchyk.ride.domain

import com.shevchyk.core.domain.{CompanyId, RideId, RideShareTokenId}
import zio.json.*

import java.security.SecureRandom
import java.time.{Duration, Instant}
import java.util.Base64

/**
 * A public, opaque token that grants read-only tracking access to exactly one ride. Possession of the token is the only
 * authorization — there is no JWT — so the token value must be high-entropy and non-enumerable (NOT a UUID). The token
 * lives while the ride is active plus a buffer after it ends; see [[RideShareToken.isWithinTrackingWindow]].
 */
final case class RideShareToken(
    id: RideShareTokenId,
    token: String,
    rideId: RideId,
    companyId: CompanyId,
    createdAt: Instant,
    expiresAt: Instant
) derives JsonCodec

object RideShareToken:

  /**
   * Buffer after a ride ends (Completed/Cancelled/HandedOff) during which the tracking link still resolves, so a client
   * who opens it just after drop-off still sees the final state instead of a dead link.
   */
  val DefaultTrackingBuffer: Duration = Duration.ofMinutes(90)

  private val secureRandom = new SecureRandom()

  /**
   * Generate a fresh, URL-safe, non-padded Base64 token from 32 random bytes (~256 bits of entropy, ~43 chars). This is
   * intentionally NOT a UUID: a UUID is guessable/enumerable and time-ordered, which would let an attacker probe for
   * other rides' links.
   */
  def generateTokenValue(): String =
    val bytes = new Array[Byte](32)
    secureRandom.nextBytes(bytes)
    Base64.getUrlEncoder.withoutPadding().encodeToString(bytes)

  /**
   * Whether a guest may still track this ride at `now`. Active rides (Requested/Assigned/Confirmed/InProgress) are
   * always trackable — Requested is allowed so the link can be shared at booking time (it shows "finding a driver").
   * Terminal rides (Completed/Cancelled/HandedOff) are trackable only within `bufferAfterEnd` of their end time
   * (`endTime`, falling back to `requestTime` for rides that ended without a recorded `endTime`).
   *
   * This is a pure function so it can be unit-tested deterministically against an explicit `now`.
   */
  def isWithinTrackingWindow(
      ride: com.shevchyk.ride.domain.Ride,
      now: Instant,
      bufferAfterEnd: Duration = DefaultTrackingBuffer
  ): Boolean =
    import com.shevchyk.ride.domain.RideStatus.*
    ride.status match
      case Requested | Assigned | Confirmed | InProgress => true
      case Completed | Cancelled | HandedOff             =>
        val endedAt = ride.endTime.getOrElse(ride.requestTime)
        !now.isAfter(endedAt.plus(bufferAfterEnd))
