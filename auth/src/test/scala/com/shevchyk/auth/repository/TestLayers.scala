package com.shevchyk.auth.repository

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.repository.{
  ClientCompanyRepository,
  InMemoryClientCompanyRepository,
  PersonRepository,
  SessionRepository
}
import zio.*

object TestLayers {
  val inMemoryTokenRepository: ZLayer[Any, Nothing, TokenRepository] = ZLayer.succeed(InMemoryTokenRepository())

  val inMemoryPersonRepository: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    InMemoryPersonRepositoryWithUsers()
  )

  val inMemoryClientCompanyRepository: ZLayer[Any, Nothing, ClientCompanyRepository] = ZLayer.succeed(
    new InMemoryClientCompanyRepository
  )

  val authServiceWithInMemory: ZLayer[Any, Nothing, AuthService] =
    (inMemoryPersonRepository ++ inMemoryTokenRepository ++ SessionRepository.inMemory ++
      inMemoryClientCompanyRepository ++
      (JwtConfig.live.orDie >>> JwtService.live)) >>> AuthService.live
}
