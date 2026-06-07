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
      } @@ TestAspect.withLiveClock
    )
}
