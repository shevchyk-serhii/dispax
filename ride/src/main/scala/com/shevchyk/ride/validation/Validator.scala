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

  def compose[A, B](validatorA: Validator[A], validatorB: Validator[B]): Validator[(A, B)] =
    new Validator[(A, B)]:
      type Error = Either[validatorA.Error, validatorB.Error]
      def validate(tuple: (A, B)): IO[Error, (A, B)] =
        for {
          a <- validatorA.validate(tuple._1).mapError(Left(_))
          b <- validatorB.validate(tuple._2).mapError(Right(_))
        } yield (a, b)
