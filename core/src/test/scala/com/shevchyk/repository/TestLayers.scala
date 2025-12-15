package com.shevchyk.repository

import zio.*

object TestLayers {
  val mockPersonRepository: ZLayer[Any, Nothing, PersonRepository] = 
    ZLayer.succeed(MockPersonRepository())
}