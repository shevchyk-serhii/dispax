package com.shevchyk.ride.validation

import com.shevchyk.ride.domain.RideError
import zio.*
import zio.test.*

/**
 * Verifies that `Validator.accumulate` collects *all* failures rather than stopping at the first one, and that it
 * succeeds with the original value when every check passes.
 */
object AccumulatingValidationSpec extends ZIOSpecDefault {

  private def fail(msg: String): IO[RideError, Unit] = ZIO.fail(RideError.ValidationError(msg))
  private val ok: IO[RideError, Unit]                = ZIO.unit

  def spec =
    suite("Validator.accumulate")(
      test("returns the value unchanged when all checks pass") {
        for result <- Validator.accumulate("payload")(ok, ok, ok).either
        yield assertTrue(result == Right("payload"))
      },
      test("collects every failure, not just the first") {
        for result <- Validator.accumulate("payload")(fail("a"), ok, fail("b"), fail("c")).either
        yield assertTrue(
          result.isLeft,
          result.left.toOption.get.toChunk.collect { case RideError.ValidationError(m) => m }.toSet ==
            Set("a", "b", "c")
        )
      },
      test("a single failure is still reported") {
        for result <- Validator.accumulate(42)(ok, fail("only")).either
        yield assertTrue(
          result.left.toOption.exists(_.toChunk.size == 1)
        )
      }
    )
}
