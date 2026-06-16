package com.shevchyk.core.domain

import io.github.iltotore.iron.*
import io.github.iltotore.iron.constraint.all.*
import sttp.tapir.Schema
import zio.json.{JsonDecoder, JsonEncoder}

/**
 * Compile-time refined types built on iron. Each opaque type pairs a base type with a constraint, so a value that
 * doesn't satisfy the invariant simply cannot be constructed — the check moves from scattered runtime validators into
 * the type itself.
 *
 * This file is additive: existing `case class` fields (e.g. `Person.email: String`) are unchanged for now, so nothing
 * breaks. New code can adopt these types incrementally, and fields can be migrated to them one at a time. iron's
 * runtime ops give `.either`/`.option` smart constructors for parsing untrusted input (HTTP/DB), while compile-time
 * literals are accepted via the `apply` smart constructor.
 *
 * The codecs are built explicitly from the *base* type's codec rather than `summon`-ing the iron `A :| C` instance:
 * inside the companion the opaque type unifies with `A :| C`, so summoning a refined codec would resolve back to the
 * given being defined and recurse forever. Encoding reuses the base encoder (the value is the base type at runtime);
 * decoding runs the base decoder then re-validates via the `RefinedTypeOps` smart constructor.
 */
object RefinedTypes:

  /** Builds a refined-type codec pair from the base codec plus the type's smart constructor — no recursion. */
  private def refinedJson[Base, T](
      ops: RefinedTypeOps[Base, ?, T]
  )(using baseEnc: JsonEncoder[Base], baseDec: JsonDecoder[Base]): (JsonEncoder[T], JsonDecoder[T]) =
    val enc = baseEnc.contramap[T](t => t.asInstanceOf[Base])
    val dec = baseDec.mapOrFail(ops.either)
    (enc, dec)

  // -- Email -----------------------------------------------------------------
  // A pragmatic "something@something" shape; full RFC-5322 is intentionally not
  // attempted (it's not worth the false negatives for a business app).
  private type EmailConstraint = Match["^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"]
  opaque type Email            = String :| EmailConstraint
  object Email extends RefinedTypeOps[String, EmailConstraint, Email]:
    private val (e, d)       = refinedJson(this)
    given JsonEncoder[Email] = e
    given JsonDecoder[Email] = d
    given Schema[Email]      = Schema.string

  // -- PhoneNumber -----------------------------------------------------------
  // E.164-ish: optional leading +, then 6–15 digits.
  private type PhoneConstraint = Match["^\\+?[0-9]{6,15}$"]
  opaque type PhoneNumber      = String :| PhoneConstraint
  object PhoneNumber extends RefinedTypeOps[String, PhoneConstraint, PhoneNumber]:
    private val (e, d)             = refinedJson(this)
    given JsonEncoder[PhoneNumber] = e
    given JsonDecoder[PhoneNumber] = d
    given Schema[PhoneNumber]      = Schema.string

  // -- NonEmptyName ----------------------------------------------------------
  private type NameConstraint = MinLength[1] & MaxLength[200]
  opaque type NonEmptyName    = String :| NameConstraint
  object NonEmptyName extends RefinedTypeOps[String, NameConstraint, NonEmptyName]:
    private val (e, d)              = refinedJson(this)
    given JsonEncoder[NonEmptyName] = e
    given JsonDecoder[NonEmptyName] = d
    given Schema[NonEmptyName]      = Schema.string

  // -- Geographic coordinates ------------------------------------------------
  private type LatConstraint = GreaterEqual[-90.0] & LessEqual[90.0]
  opaque type Latitude       = Double :| LatConstraint
  object Latitude extends RefinedTypeOps[Double, LatConstraint, Latitude]:
    private val (e, d)          = refinedJson(this)
    given JsonEncoder[Latitude] = e
    given JsonDecoder[Latitude] = d
    // Schema is invariant; the refined type shares Double's wire form, so reuse it.
    given Schema[Latitude] = Schema.schemaForDouble.as[Latitude]

  private type LonConstraint = GreaterEqual[-180.0] & LessEqual[180.0]
  opaque type Longitude      = Double :| LonConstraint
  object Longitude extends RefinedTypeOps[Double, LonConstraint, Longitude]:
    private val (e, d)           = refinedJson(this)
    given JsonEncoder[Longitude] = e
    given JsonDecoder[Longitude] = d
    given Schema[Longitude]      = Schema.schemaForDouble.as[Longitude]

  // -- Money -----------------------------------------------------------------
  // Non-negative monetary amount (prices, fees never go below zero).
  private type AmountConstraint = GreaterEqual[0.0]
  opaque type NonNegativeAmount = BigDecimal :| AmountConstraint
  object NonNegativeAmount extends RefinedTypeOps[BigDecimal, AmountConstraint, NonNegativeAmount]:
    private val (e, d)                   = refinedJson(this)
    given JsonEncoder[NonNegativeAmount] = e
    given JsonDecoder[NonNegativeAmount] = d
    given Schema[NonNegativeAmount]      = Schema.schemaForBigDecimal.as[NonNegativeAmount]
