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
        },
        test("'user@localhost' without TLD dot is invalid — mutation guard for TLD regex part") {
          // The constraint requires a dot after the @-domain: ^[^@\s]+@[^@\s]+\.[^@\s]+$
          // A mutant that removes '\\.[^@\\s]+' would accept 'user@localhost'
          assertTrue(
            Email.either("user@localhost").isLeft &&
              Email.either("user@example.com").isRight
          )
        }
      ),
      suite("PhoneNumber")(
        test("phone of 6 digits is valid (minimum length boundary)") {
          // Constraint: {6,15}. A mutant changing it to {1,15} would wrongly accept 1-5 digit strings.
          assertTrue(PhoneNumber.either("123456").isRight)
        },
        test("phone of 5 or fewer digits is invalid — mutation guard for min-length 6") {
          assertTrue(
            PhoneNumber.either("12345").isLeft &&
              PhoneNumber.either("1").isLeft
          )
        },
        test("phone with leading + and 6 digits is valid") {
          assertTrue(PhoneNumber.either("+123456").isRight)
        },
        test("phone of 15 digits is valid (maximum length boundary)") {
          assertTrue(PhoneNumber.either("123456789012345").isRight)
        },
        test("phone of 16 digits is invalid") {
          assertTrue(PhoneNumber.either("1234567890123456").isLeft)
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
        },
        test("Latitude -90.0 is valid (inclusive lower bound) — mutation guard for lower bound -90") {
          // A mutant changing GreaterEqual[-90.0] to GreaterEqual[-91.0] would still pass -90.0,
          // so we also assert that -90.5 is rejected — that distinguishes -90 from -91 as lower bound.
          assertTrue(
            Latitude.either(-90.0).isRight &&
              Latitude.either(-90.5).isLeft
          )
        },
        test("Longitude -180.0 is valid (inclusive lower bound) — mutation guard for lower bound -180") {
          // A mutant changing GreaterEqual[-180.0] to GreaterEqual[-181.0] would still pass -180.0;
          // asserting -180.5 is invalid distinguishes the two bounds.
          assertTrue(
            Longitude.either(-180.0).isRight &&
              Longitude.either(-180.5).isLeft
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
