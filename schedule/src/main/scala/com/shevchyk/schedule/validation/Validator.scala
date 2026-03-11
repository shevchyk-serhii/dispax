package com.shevchyk.schedule.validation

import zio.*

trait Validator[A]:
  type Error
  def validate(value: A): IO[Error, A]

object Validator:

  type Aux[A, E] = Validator[A] { type Error = E }

  def apply[A](using validator: Validator[A]): Validator.Aux[A, validator.Error] = validator

  extension [A](value: A)
    def validate(using validator: Validator[A]): IO[validator.Error, A] = validator.validate(value)
