package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.{CompanyId, RideId, RideShareTokenId}
import com.shevchyk.ride.domain.{RideError, RideShareToken}
import com.shevchyk.ride.domain.RepositoryExtensions.*
import com.shevchyk.ride.repository.{RideRepository, RideShareTokenRepository}
import zio.*

import java.time.Duration

/**
 * The ride a resolved guest token grants tracking access to. Carries only ids — the public DTO (with ETA and driver
 * location) is assembled in the api layer, which is where `EtaService` lives (the `ride` module must not depend on
 * `driver`).
 */
final case class ResolvedShare(rideId: RideId, companyId: CompanyId)

trait RideShareTokenService:
  /**
   * Mint (or reuse) a public tracking token for a ride. Tenant-gated: fails unless the ride belongs to `companyId`.
   * Idempotent — returns the existing live token for the ride if one exists, otherwise creates a fresh one.
   */
  def generateForRide(rideId: RideId, companyId: CompanyId): IO[RideError, String]

  /**
   * Resolve a token value to the ride it tracks, or fail with [[RideError.ShareTokenInvalid]] when the token is
   * unknown, DB-expired, or the ride is outside its tracking window. Not-found and out-of-window collapse into the same
   * error so callers map both to 404 (no existence leak).
   */
  def resolve(token: String): IO[RideError, ResolvedShare]

final class RideShareTokenServiceImpl(
    shareTokenRepository: RideShareTokenRepository,
    rideRepository: RideRepository,
    trackingBuffer: Duration
) extends RideShareTokenService:

  // Hard cap stored as the DB `expires_at`; the fine-grained live/buffer check happens at resolve time against the
  // current ride status. 24h past pickup comfortably covers any ride plus its post-end buffer.
  private val HardExpiryAfterPickup: Duration = Duration.ofHours(24)

  override def generateForRide(rideId: RideId, companyId: CompanyId): IO[RideError, String] =
    for {
      ride     <- rideRepository.findById(rideId).mapDatabaseError.flatMap {
                    case Some(r) => ZIO.succeed(r)
                    case None    => ZIO.fail(RideError.RideNotFound(rideId))
                  }
      // Tenant gate: a staff member may only generate a link for a ride of their own company.
      _        <- ZIO
                    .fail(RideError.UnauthorizedAccess(ride.clientId, rideId))
                    .when(ride.companyId != companyId)
      existing <- shareTokenRepository.findActiveByRideId(rideId).mapDatabaseError
      token    <-
        existing match
          case Some(t) => ZIO.succeed(t.token)
          case None    =>
            for {
              now      <- Clock.instant
              expiresAt = {
                val byPickup = ride.pickupDateTime.plus(HardExpiryAfterPickup)
                val byNow    = now.plus(HardExpiryAfterPickup)
                if byPickup.isAfter(byNow) then byPickup else byNow
              }
              fresh     = RideShareToken(
                            id = RideShareTokenId.generate(),
                            token = RideShareToken.generateTokenValue(),
                            rideId = rideId,
                            companyId = companyId,
                            createdAt = now,
                            expiresAt = expiresAt
                          )
              _        <- shareTokenRepository.create(fresh).mapDatabaseError
            } yield fresh.token
    } yield token

  override def resolve(token: String): IO[RideError, ResolvedShare] =
    for {
      now    <- Clock.instant
      record <- shareTokenRepository.findByToken(token).mapDatabaseError.someOrFail(RideError.ShareTokenInvalid)
      // DB-level hard expiry.
      _      <- ZIO.fail(RideError.ShareTokenInvalid).when(!record.expiresAt.isAfter(now))
      ride   <- rideRepository.findById(record.rideId).mapDatabaseError.someOrFail(RideError.ShareTokenInvalid)
      // Fine-grained status + post-end buffer window.
      _      <- ZIO
                  .fail(RideError.ShareTokenInvalid)
                  .when(!RideShareToken.isWithinTrackingWindow(ride, now, trackingBuffer))
    } yield ResolvedShare(record.rideId, record.companyId)

object RideShareTokenService:

  val layer: ZLayer[RideShareTokenRepository & RideRepository, Nothing, RideShareTokenService] = ZLayer.fromFunction(
    (stRepo: RideShareTokenRepository, rideRepo: RideRepository) =>
      RideShareTokenServiceImpl(stRepo, rideRepo, RideShareToken.DefaultTrackingBuffer)
  )
