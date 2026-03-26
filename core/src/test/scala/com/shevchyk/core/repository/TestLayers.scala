package com.shevchyk.core.repository

import zio.*

object TestLayers {
  val inMemoryPersonRepository: ZLayer[Any, Nothing, PersonRepository] =
    InMemoryPersonRepository.layer
}
