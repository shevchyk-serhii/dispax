package com.shevchyk.core.domain

import com.shevchyk.core.domain.RefinedTypes.*
import io.github.iltotore.iron.*
import zio.json.*
import zio.test.*

/**
 * Demonstrates the iron refined types: compile-time literals are accepted via `autoRefine`, runtime parsing via
 * `.either` rejects invalid input, and the zio-json codecs round-trip valid values while refusing invalid ones.
 */
object RefinedTypesSpec extends ZIOSpecDefault {

  def spec =
    suite("RefinedTypes")(
      suite("Email")(
        test("accepts a valid literal via the smart constructor") {
          val e = Email("user@example.com")
          assertTrue(e == Email.applyUnsafe("user@example.com"))
        },
        test("runtime parsing rejects an invalid address") {
          assertTrue(Email.either("not-an-email").isLeft, Email.either("a@b.co").isRight)
        },
        test("JSON round-trips a valid value and rejects an invalid one") {
          val e = Email("user@example.com")
          assertTrue(
            e.toJson.fromJson[Email] == Right(e),
            "\"nope\"".fromJson[Email].isLeft
          )
        }
      ),
      suite("Latitude / Longitude")(
        test("accepts in-range literals") {
          val lat = Latitude(48.137)
          val lon = Longitude(11.575)
          assertTrue(lat == Latitude.applyUnsafe(48.137), lon == Longitude.applyUnsafe(11.575))
        },
        test("rejects out-of-range values at runtime") {
          assertTrue(
            Latitude.either(91.0).isLeft,
            Latitude.either(-90.0).isRight,
            Longitude.either(181.0).isLeft
          )
        }
      ),
      suite("NonNegativeAmount")(
        test("rejects negatives, accepts zero and positives") {
          assertTrue(
            NonNegativeAmount.either(BigDecimal(-1)).isLeft,
            NonNegativeAmount.either(BigDecimal(0)).isRight,
            NonNegativeAmount.either(BigDecimal("19.99")).isRight
          )
        }
      )
    )
}
