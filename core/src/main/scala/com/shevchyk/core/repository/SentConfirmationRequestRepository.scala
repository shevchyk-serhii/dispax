package com.shevchyk.core.repository

import com.shevchyk.core.domain.{PersonId, RideId}
import zio.*

/**
 * Repository that tracks which drivers have already received a confirmation-request push for a ride. Used by the
 * morning scheduler to avoid duplicate push notifications and by the RideService to clear the dedup state on
 * confirm/reject/reassign.
 *
 * The PostgreSQL implementation lives in the `notification` module (needs Doobie); the in-memory implementation is here
 * (shared by unit tests across modules that depend on `core`).
 */
trait SentConfirmationRequestRepository:
  def isAlreadySent(rideId: RideId, personId: PersonId): Task[Boolean]
  def markSent(rideId: RideId, personId: PersonId): Task[Unit]

  /**
   * Atomically records a confirmation request for (ride, person), returning `true` only if this call inserted a *new*
   * record. Lets callers deduplicate without a check-then-act race: two concurrent scheduler ticks (e.g. two Cloud Run
   * instances) cannot both observe `true`. Mirrors `EtaAlertRepository.markAlertedIfNew`.
   */
  def markSentIfNew(rideId: RideId, personId: PersonId): Task[Boolean]
  // Clear all confirmation-request records for a ride (called on confirm, reject or reassign).
  def clear(rideId: RideId): Task[Unit]

object SentConfirmationRequestRepository:

  val inMemory: ZLayer[Any, Nothing, SentConfirmationRequestRepository] = ZLayer.succeed(
    InMemorySentConfirmationRequestRepository()
  )

final class InMemorySentConfirmationRequestRepository extends SentConfirmationRequestRepository:

  private val sent = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe.run(Ref.make(Set.empty[(java.util.UUID, java.util.UUID)])).getOrThrowFiberFailure()
  }

  override def isAlreadySent(rideId: RideId, personId: PersonId): Task[Boolean] = sent.get.map(
    _.contains((rideId.value, personId.value))
  )

  override def markSent(rideId: RideId, personId: PersonId): Task[Unit] = sent.update(
    _ + ((rideId.value, personId.value))
  )

  override def markSentIfNew(rideId: RideId, personId: PersonId): Task[Boolean] = sent.modify { s =>
    val key = (rideId.value, personId.value)
    if s.contains(key) then (false, s) else (true, s + key)
  }

  override def clear(rideId: RideId): Task[Unit] = sent.update(_.filter { case (rid, _) => rid != rideId.value })
