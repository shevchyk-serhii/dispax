package com.shevchyk.auth.integration

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.repository.{InMemoryPersonRepositoryWithUsers, InMemoryTokenRepository}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.core.repository.{InMemorySessionRepository, PersonRepository, SessionRepository}
import java.util.UUID
import zio.*
import zio.test.*

object AuthFlowIntegrationSpec extends ZIOSpecDefault {

  /**
   * Fresh layers per test to avoid shared mutable state
   */
  def layers: ZLayer[Any, Nothing, AuthService] =
    (ZLayer.succeed(InMemoryPersonRepositoryWithUsers()) ++
      ZLayer.succeed(InMemoryTokenRepository()) ++
      ZLayer.succeed[SessionRepository](InMemorySessionRepository()) ++
      (JwtConfig.live.orDie >>> JwtService.live)) >>> AuthService.live

  // Variant exposing the PersonRepository so the delete-flow tests can stamp a companyId on the
  // created user (createUser leaves it None) and then exercise the tenant-scoped deleteUser.
  def layersWithRepo: ZLayer[Any, Nothing, AuthService & PersonRepository] = {
    val repo = ZLayer.succeed[PersonRepository](InMemoryPersonRepositoryWithUsers())
    val auth =
      (repo ++ ZLayer.succeed(InMemoryTokenRepository()) ++
        ZLayer.succeed[SessionRepository](InMemorySessionRepository()) ++
        (JwtConfig.live.orDie >>> JwtService.live)) >>> AuthService.live
    repo ++ auth
  }

  def spec =
    suite("AuthFlow Integration")(
      test("createUser → login → validateToken full cycle") {
        for {
          service   <- ZIO.service[AuthService]
          _         <- service.createUser(
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
        val companyId = CompanyId(UUID.randomUUID())
        for {
          repo    <- ZIO.service[PersonRepository]
          service <- ZIO.service[AuthService]
          user    <- service.createUser(
                       CreateUserRequest(
                         email = "flow2@example.com",
                         name = "Flow User 2",
                         role = "DRIVER",
                         password = "OldPass123"
                       )
                     )
          // changePassword is tenant-scoped; stamp the created user with a company first
          // (createUser leaves it None) so the requester's companyId matches.
          person  <- repo.findById(PersonId(user.id)).someOrFailException
          _       <- repo.update(person.copy(companyId = Some(companyId)))
          login1  <- service.login("flow2@example.com", "OldPass123")
          _       <- service.changePassword(user.id, companyId, ChangePasswordRequest("OldPass123", "NewPass456"))
          login2  <- service.login("flow2@example.com", "NewPass456")
        } yield assertTrue(
          login1.person.email == "flow2@example.com" &&
            login2.person.email == "flow2@example.com"
        )
      }.provide(layersWithRepo),
      test("createUser → deleteUser → login fails") {
        val companyId = CompanyId(UUID.randomUUID())
        for {
          repo    <- ZIO.service[PersonRepository]
          service <- ZIO.service[AuthService]
          user    <- service.createUser(
                       CreateUserRequest(
                         email = "flow3@example.com",
                         name = "Flow User 3",
                         role = "CLIENT",
                         password = "Secure123"
                       )
                     )
          // createUser leaves companyId None; stamp one so the tenant-scoped delete can target it.
          person  <- repo.findById(PersonId(user.id)).someOrFailException
          _       <- repo.update(person.copy(companyId = Some(companyId)))
          _       <- service.deleteUser(user.id, companyId)
          result  <- service.login("flow3@example.com", "Secure123").exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[UserNotFound])
          case _                   => false
        })
      }.provide(layersWithRepo),
      test("login → validateToken → deleteUser → validateToken fails") {
        val companyId = CompanyId(UUID.randomUUID())
        for {
          repo      <- ZIO.service[PersonRepository]
          service   <- ZIO.service[AuthService]
          user      <- service.createUser(
                         CreateUserRequest(
                           email = "flow4@example.com",
                           name = "Flow User 4",
                           role = "CLIENT",
                           password = "Secure123"
                         )
                       )
          person    <- repo.findById(PersonId(user.id)).someOrFailException
          _         <- repo.update(person.copy(companyId = Some(companyId)))
          login     <- service.login("flow4@example.com", "Secure123")
          validated <- service.validateToken(login.token)
          _         <- service.deleteUser(user.id, companyId)
          result    <- service.validateToken(login.token).exit
        } yield assertTrue(
          validated.email == "flow4@example.com" &&
            result.isFailure
        )
      }.provide(layersWithRepo)
    ) @@ TestAspect.tag("integration")
}
