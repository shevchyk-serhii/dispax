package com.shevchyk.auth.middleware

import zio.*
import zio.test.*

object RateLimiterSpec extends ZIOSpecDefault {

  def spec =
    suite("RateLimiter")(
      test("allows requests under the limit") {
        for {
          limiter <- RateLimiter.make(maxRequests = 5, windowSeconds = 60)
          r1      <- limiter.checkRate("user1")
          r2      <- limiter.checkRate("user1")
          r3      <- limiter.checkRate("user1")
        } yield assertTrue(r1 && r2 && r3)
      },
      test("blocks at limit + 1") {
        for {
          limiter <- RateLimiter.make(maxRequests = 3, windowSeconds = 60)
          _       <- limiter.checkRate("user1")
          _       <- limiter.checkRate("user1")
          _       <- limiter.checkRate("user1")
          blocked <- limiter.checkRate("user1")
        } yield assertTrue(!blocked)
      },
      test("different keys are independent") {
        for {
          limiter <- RateLimiter.make(maxRequests = 2, windowSeconds = 60)
          _       <- limiter.checkRate("user1")
          _       <- limiter.checkRate("user1")
          blocked <- limiter.checkRate("user1")
          allowed <- limiter.checkRate("user2")
        } yield assertTrue(!blocked && allowed)
      },
      test("allows exactly maxRequests") {
        for {
          limiter <- RateLimiter.make(maxRequests = 5, windowSeconds = 60)
          results <- ZIO.foreach((1 to 5).toList)(_ => limiter.checkRate("user1"))
          sixth   <- limiter.checkRate("user1")
        } yield assertTrue(results.forall(_ == true) && !sixth)
      },
      test("custom params respected") {
        for {
          limiter <- RateLimiter.make(maxRequests = 1, windowSeconds = 60)
          first   <- limiter.checkRate("user1")
          second  <- limiter.checkRate("user1")
        } yield assertTrue(first && !second)
      },
      test("window expiry allows new requests") {
        for {
          limiter <- RateLimiter.make(maxRequests = 1, windowSeconds = 1)
          first   <- limiter.checkRate("user1")
          _       <- ZIO.sleep(1500.millis)
          second  <- limiter.checkRate("user1")
        } yield assertTrue(first && second)
      } @@ TestAspect.withLiveClock,
      // [Mutant 4 killer] Rejected requests must NOT add a new timestamp to the window.
      //
      // Design: rejected calls do NOT extend the occupied window; only allowed calls do.
      // This means a client that hammers the endpoint after being blocked does NOT push
      // the window further into the future.
      //
      // Mutation to kill: changing `(false, map.updated(key, timestamps))` to
      //   `(false, map.updated(key, timestamps :+ now))` — recording a fresh timestamp
      //   on every rejected call.
      //
      // Scenario using windowSeconds=1, maxRequests=1:
      //   t=0     : allowed → [T0] stored
      //   t=600ms : rejected
      //              Correct  : [T0] unchanged (or cleaned); T0 is still the only entry
      //              Mutant   : [T0, T_rej] stored where T_rej ≈ 600ms after T0
      //   t=1100ms: allowed timestamp T0 is now older than 1s → falls out of the window
      //              Correct  : window is empty   → checkRate returns true  (allowed)
      //              Mutant   : T_rej is ~500ms old, still inside the window → checkRate
      //                         returns false (blocked)  ← test catches this
      test("rejected request does not extend the window past the last allowed call") {
        for {
          limiter  <- RateLimiter.make(maxRequests = 1, windowSeconds = 1)
          allowed  <- limiter.checkRate("key") // t≈0  stored as T0
          rejected <- limiter.checkRate("key") // t≈0  blocked; correct impl: T0 only; mutant: [T0, T_rej]
          _        <- ZIO.sleep(600.millis)    // let 600ms pass — T0 is now 600ms old
          rej2     <- limiter.checkRate("key") // still blocked (T0 < 1s old)
          _        <- ZIO.sleep(600.millis)    // total 1200ms from T0 → T0 ages out; T_rej (~600ms) still live if stored
          // Correct  : window empty   → allowed
          // Mutant   : T_rej ~600ms old, inside 1s window → blocked
          result   <- limiter.checkRate("key")
        } yield assertTrue(allowed && !rejected && !rej2 && result)
      } @@ TestAspect.withLiveClock,
      // [Eviction] Keys whose whole window has expired must be removed from the state map on the
      // next access, otherwise every key ever seen (e.g. every source IP of a login attempt) keeps
      // a permanent entry and the map grows without bound for the life of the process.
      //
      // Mutation to kill: dropping the sweep (`map.filter(...)`) and putting keys back verbatim —
      // "stale-ip" would then still be tracked after its window expired.
      test("expired keys are evicted from the state map on the next access") {
        for {
          limiter <- RateLimiter.make(maxRequests = 1, windowSeconds = 1)
          _       <- limiter.checkRate("stale-ip")
          _       <- ZIO.sleep(1500.millis)        // let the whole "stale-ip" window expire
          _       <- limiter.checkRate("fresh-ip") // any later call sweeps expired buckets
          keys    <- limiter.trackedKeys
        } yield assertTrue(!keys.contains("stale-ip"), keys.contains("fresh-ip"))
      } @@ TestAspect.withLiveClock,
      test("a key with live timestamps survives the sweep") {
        for {
          limiter <- RateLimiter.make(maxRequests = 5, windowSeconds = 60)
          _       <- limiter.checkRate("live-ip")
          _       <- limiter.checkRate("other-ip")
          keys    <- limiter.trackedKeys
        } yield assertTrue(keys.contains("live-ip"), keys.contains("other-ip"))
      }
      // [Mutant 5 — window cutoff off-by-one: windowSeconds → windowSeconds - 1]
      // Pinning the exact boundary requires recording a timestamp at precisely
      // `now.minusSeconds(windowSeconds)` and then checking it, which is not achievable
      // without hardware-level time control.  Off-by-one shifts the cutoff by 1 second;
      // detecting it reliably would require sleeping exactly `windowSeconds` between the
      // recording and the re-check, with sub-second accuracy.  Test skipped to avoid flak.
    )
}
