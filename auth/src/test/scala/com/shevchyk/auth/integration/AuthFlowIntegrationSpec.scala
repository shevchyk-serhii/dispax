package com.shevchyk.auth.integration

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.repository.{InMemoryPersonRepositoryWithUsers, InMemoryTokenRepository, TestLayers}
import com.shevchyk.auth.service.JwtService
import zio.*
import zio.test.*

object AuthFlowIntegrationSpec extends ZIOSpecDefault {

  /**
   * Fresh layers per test to avoid shared mutable state
   */
  def layers: ZLayer[Any, Nothing, AuthService] =
    (ZLayer.succeed(InMemoryPersonRepositoryWithUsers()) ++
      ZLayer.succeed(InMemoryTokenRepository()) ++
      (JwtConfig.live >>> JwtService.live)) >>> AuthService.live

  def spec =
    suite("AuthFlow Integration")(
      test("createUser → login → validateToken full cycle") {
        for {
          service   <- ZIO.service[AuthService]
          user      <- service.createUser(
                         CreateUserRequest(
                           email = "flow1@example.com",
                           name = "Flow User",
                           role = "CLIENT",
                           password = "Secure123"
                         )
                       )
          login     <- service.login("flow1@example.com", "Secure123")
          validated <- service.validateToken(login.token)
        } yield assertTrue(
          validated.email == "flow1@example.com" &&
            validated.name == "Flow User" &&
            validated.role == "CLIENT"
        )
      }.provide(layers),
      test("createUser → login → changePassword → login with new password") {
        for {
          service <- ZIO.service[AuthService]
          user    <- service.createUser(
                       CreateUserRequest(
                         email = "flow2@example.com",
                         name = "Flow User 2",
                         role = "DRIVER",
                         password = "OldPass123"
                       )
                     )
          login1  <- service.login("flow2@example.com", "OldPass123")
          _       <- service.changePassword(user.id, ChangePasswordRequest("OldPass123", "NewPass456"))
          login2  <- service.login("flow2@example.com", "NewPass456")
        } yield assertTrue(
          login1.person.email == "flow2@example.com" &&
            login2.person.email == "flow2@example.com"
        )
      }.provide(layers),
      test("createUser → deleteUser → login fails") {
        for {
          service <- ZIO.service[AuthService]
          user    <- service.createUser(
                       CreateUserRequest(
                         email = "flow3@example.com",
                         name = "Flow User 3",
                         role = "CLIENT",
                         password = "Secure123"
                       )
                     )
          _       <- service.deleteUser(user.id)
          result  <- service.login("flow3@example.com", "Secure123").exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserNotFound])
          case _                   => false
        })
      }.provide(layers),
      test("login → validateToken → deleteUser → validateToken fails") {
        for {
          service   <- ZIO.service[AuthService]
          user      <- service.createUser(
                         CreateUserRequest(
                           email = "flow4@example.com",
                           name = "Flow User 4",
                           role = "CLIENT",
                           password = "Secure123"
                         )
                       )
          login     <- service.login("flow4@example.com", "Secure123")
          validated <- service.validateToken(login.token)
          _         <- service.deleteUser(user.id)
          result    <- service.validateToken(login.token).exit
        } yield assertTrue(
          validated.email == "flow4@example.com" &&
            result.isFailure
        )
      }.provide(layers)
    )
}
