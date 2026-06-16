package com.shevchyk.ride.validation

import zio.*

trait Validator[A]:
  type Error
  def validate(value: A): IO[Error, A]

object Validator:

  type Aux[A, E] = Validator[A] { type Error = E }

  def apply[A](using validator: Validator[A]): Validator.Aux[A, validator.Error] = validator

  extension [A](value: A)
    def validate(using validator: Validator[A]): IO[validator.Error, A] = validator.validate(value)

  def validateAll[A](values: List[A])(using validator: Validator[A]): IO[validator.Error, List[A]] =
    ZIO.foreach(values)(_.validate)

  /**
   * Runs several independent field checks and accumulates *all* failures instead of stopping at the first one. This is
   * the building block for form-style validation where the client should see every problem at once.
   *
   * Each check is an `IO[E, Unit]`; on success the original `value` is returned, otherwise a `NonEmptyChunk[E]` with
   * every error that occurred. Use this in place of a fail-fast `for`-comprehension when better UX is worth collecting
   * all errors.
   */
  def accumulate[E, A](value: A)(checks: IO[E, Unit]*): IO[NonEmptyChunk[E], A] = ZIO
    .validatePar(checks)(identity)
    .mapError(NonEmptyChunk.fromCons)
    .as(value)

  def compose[A, B](validatorA: Validator[A], validatorB: Validator[B]): Validator[(A, B)] =
    new Validator[(A, B)]:
      type Error = Either[validatorA.Error, validatorB.Error]
      def validate(tuple: (A, B)): IO[Error, (A, B)] =
        for {
          a <- validatorA.validate(tuple._1).mapError(Left(_))
          b <- validatorB.validate(tuple._2).mapError(Right(_))
        } yield (a, b)
