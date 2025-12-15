package com.shevchyk.auth.repository

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import zio.*

object TestLayers {
  val inMemoryUserRepository: ZLayer[Any, Nothing, UserRepository] = 
    ZLayer.succeed(InMemoryUserRepository())
    
  val inMemoryTokenRepository: ZLayer[Any, Nothing, TokenRepository] = 
    ZLayer.succeed(InMemoryTokenRepository())
    
  val authServiceWithInMemory: ZLayer[Any, Nothing, AuthService] = 
    (inMemoryUserRepository ++ inMemoryTokenRepository ++ (JwtConfig.development >>> JwtService.live)) >>> AuthService.live
}