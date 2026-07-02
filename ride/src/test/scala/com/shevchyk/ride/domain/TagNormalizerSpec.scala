package com.shevchyk.ride.domain

import zio.test.*

object TagNormalizerSpec extends ZIOSpecDefault {

  def spec =
    suite("TagNormalizer.normalize")(
      test("de-dups case-insensitively, keeping the first-seen casing") {
        assertTrue(TagNormalizer.normalize(List("Urgent", "urgent", "URGENT")) == List("Urgent"))
      },
      test("trims surrounding whitespace and collapses internal runs") {
        assertTrue(TagNormalizer.normalize(List("  Cash   Only ")) == List("Cash Only"))
      },
      test("drops blank / whitespace-only tags") {
        assertTrue(TagNormalizer.normalize(List("", "   ", "VIP")) == List("VIP"))
      },
      test("preserves first-seen order of distinct tags") {
        assertTrue(
          TagNormalizer.normalize(List("Regular", "Urgent", "regular", "Cash")) ==
            List("Regular", "Urgent", "Cash")
        )
      },
      test("empty input yields empty output") {
        assertTrue(TagNormalizer.normalize(Nil) == Nil)
      }
    )
}
