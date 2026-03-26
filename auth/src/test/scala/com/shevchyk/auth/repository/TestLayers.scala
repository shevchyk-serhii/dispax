package com.shevchyk.auth.repository

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.repository.PersonRepository
import zio.*

object TestLayers {
  val inMemoryTokenRepository: ZLayer[Any, Nothing, TokenRepository] =
    ZLayer.succeed(InMemoryTokenRepository())

  val inMemoryPersonRepository: ZLayer[Any, Nothing, PersonRepository] =
    ZLayer.succeed(InMemoryPersonRepositoryWithUsers())

  val authServiceWithInMemory: ZLayer[Any, Nothing, AuthService] =
    (inMemoryPersonRepository ++ inMemoryTokenRepository ++ (JwtConfig.live >>> JwtService.live)) >>> AuthService.live
}
