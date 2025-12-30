package com.shevchyk.auth.repository

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.repository.{PersonRepository, MockPersonRepository}
import zio.*

object TestLayers {
  val inMemoryUserRepository: ZLayer[Any, Nothing, UserRepository] =
    ZLayer.succeed(InMemoryUserRepository())

  val inMemoryTokenRepository: ZLayer[Any, Nothing, TokenRepository] =
    ZLayer.succeed(InMemoryTokenRepository())

  val mockPersonRepository: ZLayer[Any, Nothing, PersonRepository] =
    ZLayer.succeed(MockPersonRepository())

  val authServiceWithInMemory: ZLayer[Any, Nothing, AuthService] =
    (inMemoryUserRepository ++ inMemoryTokenRepository ++ mockPersonRepository ++ (JwtConfig.development >>> JwtService.live)) >>> AuthService.live
}