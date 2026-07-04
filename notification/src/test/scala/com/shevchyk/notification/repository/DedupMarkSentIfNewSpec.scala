package com.shevchyk.notification.repository

import com.shevchyk.core.domain.{PersonId, RideId}
import com.shevchyk.core.repository.InMemorySentConfirmationRequestRepository
import zio.*
import zio.test.*

import java.util.UUID

/**
 * Unit tests for the atomic `markSentIfNew` dedup primitive on the in-memory doubles. The contract (mirroring
 * `EtaAlertRepository.markAlertedIfNew`): exactly ONE of any number of concurrent callers observes `true` — no
 * check-then-act window in which two callers can both decide to send a push.
 */
object DedupMarkSentIfNewSpec extends ZIOSpecDefault:

  private val rideId   = RideId(UUID.fromString("00000003-0000-0000-0000-000000000003"))
  private val driverId = PersonId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  def spec =
    suite("markSentIfNew is atomic")(
      suite("InMemorySentConfirmationRequestRepository")(
        test("first call returns true, second returns false") {
          val repo = new InMemorySentConfirmationRequestRepository
          for {
            first  <- repo.markSentIfNew(rideId, driverId)
            second <- repo.markSentIfNew(rideId, driverId)
            marked <- repo.isAlreadySent(rideId, driverId)
          } yield assertTrue(first, !second, marked)
        },
        test("of 16 concurrent callers exactly one observes true") {
          val repo = new InMemorySentConfirmationRequestRepository
          for {
            results <- ZIO.collectAllPar(List.fill(16)(repo.markSentIfNew(rideId, driverId)))
          } yield assertTrue(results.count(identity) == 1)
        }
      ),
      suite("InMemoryCheckpointNotificationRepository")(
        test("first call returns true, second returns false; other checkpoint types stay independent") {
          val repo = new InMemoryCheckpointNotificationRepository
          for {
            first  <- repo.markSentIfNew(rideId, driverId, "landed")
            second <- repo.markSentIfNew(rideId, driverId, "landed")
            other  <- repo.markSentIfNew(rideId, driverId, "baggage")
          } yield assertTrue(first, !second, other)
        },
        test("of 16 concurrent callers exactly one observes true") {
          val repo = new InMemoryCheckpointNotificationRepository
          for {
            results <- ZIO.collectAllPar(List.fill(16)(repo.markSentIfNew(rideId, driverId, "landed")))
          } yield assertTrue(results.count(identity) == 1)
        }
      )
    )
