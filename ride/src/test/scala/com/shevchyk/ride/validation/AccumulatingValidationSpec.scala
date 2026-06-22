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
      },
      // [MEDIUM] Verify that errors are returned in input order (ZIO.validatePar preserves order)
      // and that duplicate error messages are NOT silently deduplicated — both "a" occurrences appear.
      // A mutation that reverses or deduplicates the error list would be caught by this test.
      test("errors preserve input order and are not deduplicated") {
        for result <- Validator.accumulate("v")(fail("first"), fail("second"), fail("third")).either
        yield {
          val messages = result.left.toOption.get.toChunk.collect { case RideError.ValidationError(m) => m }.toList
          assertTrue(
            messages == List("first", "second", "third")
          )
        }
      },
      test("duplicate error messages both appear (no deduplication)") {
        for result <- Validator.accumulate("v")(fail("dup"), fail("dup")).either
        yield {
          val messages = result.left.toOption.get.toChunk.collect { case RideError.ValidationError(m) => m }.toList
          assertTrue(messages.size == 2, messages == List("dup", "dup"))
        }
      }
    )
}
