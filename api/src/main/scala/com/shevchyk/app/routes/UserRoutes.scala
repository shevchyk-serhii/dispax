package com.shevchyk.app.routes

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import com.shevchyk.auth.middleware.{AuthMiddleware, AuthenticatedUser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.repository.PersonRepository
import com.shevchyk.core.domain.{Person, PersonId, PersonRole}
import com.shevchyk.notification.application.FcmService
import com.shevchyk.notification.domain.RegisterFcmTokenRequest
import java.util.UUID
import zio.*
import zio.http.*
import zio.json.*

object UserRoutes {

  private def handleAuthError(ex: Throwable): UIO[Response] =
    val (status, msg) =
      ex match
        case UserNotFound(email)       => (Status.NotFound, s"User not found: $email")
        case UserAlreadyExists(email)  => (Status.Conflict, s"User already exists: $email")
        case InvalidCredentials(_)     => (Status.Unauthorized, "Invalid credentials")
        case WeakPassword(reason)      => (Status.BadRequest, reason)
        case ValidationError(field, m) => (Status.BadRequest, s"$field: $m")
        case other                     => (Status.InternalServerError, Option(other.getMessage).getOrElse(other.toString))
    ZIO.succeed(Response(status, body = Body.fromString(s"""{"error":"$msg"}""")))

  val routes: Routes[PersonRepository, Throwable] = Routes(
    Method.GET / "api" / "stats" / "rides" -> handler { (_: Request) =>
      for {
        personRepo <- ZIO.service[PersonRepository]
        drivers    <- personRepo.findByRole(PersonRole.Driver)
        clients    <- personRepo.findByRole(PersonRole.Client)
        statsJson   =
          s"""{
          "totalRides": ${scala.util.Random.nextInt(100) + 50},
          "completedRides": ${scala.util.Random.nextInt(40) + 20},
          "inProgressRides": ${scala.util.Random.nextInt(10) + 2},
          "requestedRides": ${scala.util.Random.nextInt(15) + 5},
          "assignedRides": ${scala.util.Random.nextInt(12) + 3},
          "cancelledRides": ${scala.util.Random.nextInt(8) + 1},
          "activeDrivers": ${drivers.length},
          "totalClients": ${clients.length},
          "todayRevenue": ${scala.util.Random.nextInt(5000) + 2000}.00,
          "monthlyRevenue": ${scala.util.Random.nextInt(50000) + 25000}.00
        }"""
        response   <- ZIO.succeed(Response.json(statsJson))
      } yield response
    }
  )

  val authenticatedRoutes: Routes[AuthService & PersonRepository & JwtService & FcmService, Response] = Routes(
    // GET /api/users — list all users (dispatcher/admin)
    Method.GET / "api" / "users" / "drivers"    -> authenticatedHandler[PersonRepository] { (user, _) =>
      (for {
        _          <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        personRepo <- ZIO.service[PersonRepository]
        drivers    <- personRepo.findByRole(PersonRole.Driver)
      } yield Response.json(drivers.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },
    Method.GET / "api" / "users" / "clients"    -> authenticatedHandler[PersonRepository] { (user, _) =>
      (for {
        _          <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN", "SECRETARY")
        personRepo <- ZIO.service[PersonRepository]
        clients    <- personRepo.findByRole(PersonRole.Client)
      } yield Response.json(clients.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },
    Method.GET / "api" / "users" / string("id") -> handler { (userId: String, request: Request) =>
      (for {
        user       <- AuthMiddleware.authenticateRequest(request)
        _          <- AuthMiddleware.checkRoleOrOwner(user, UUID.fromString(userId), "DISPATCHER", "ADMIN")
        personRepo <- ZIO.service[PersonRepository]
        userOpt    <- personRepo.findById(PersonId(UUID.fromString(userId)))
        response   <-
          userOpt match {
            case Some(u) => ZIO.succeed(Response.json(u.toJson))
            case None    => ZIO.succeed(Response.status(Status.NotFound))
          }
      } yield response).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },
    Method.GET / "api" / "users"                -> authenticatedHandler[PersonRepository] { (user, _) =>
      (for {
        _          <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        personRepo <- ZIO.service[PersonRepository]
        users      <- personRepo.findAll()
      } yield Response.json(users.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },

    // POST /api/users — create user (dispatcher/admin)
    Method.POST / "api" / "users" -> authenticatedJsonHandler[AuthService, CreateUserRequest] { (user, createReq) =>
      (for {
        _       <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        service <- ZIO.service[AuthService]
        userDto <- service.createUser(createReq)
      } yield Response(Status.Created, body = Body.fromString(userDto.toJson))).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },

    // PUT /api/users/{id} — update user (dispatcher/admin or self)
    Method.PUT / "api" / "users" / string("id") -> handler { (userId: String, request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRoleOrOwner(user, UUID.fromString(userId), "DISPATCHER", "ADMIN")
        bodyStr   <- request.body.asString
        updateReq <- ZIO
                       .fromEither(bodyStr.fromJson[UpdateUserRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        service   <- ZIO.service[AuthService]
        userDto   <- service.updateUser(UUID.fromString(userId), updateReq)
      } yield Response.json(userDto.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },

    // DELETE /api/users/{id} — deactivate user (dispatcher/admin)
    Method.DELETE / "api" / "users" / string("id") -> handler { (userId: String, request: Request) =>
      (for {
        user    <- AuthMiddleware.authenticateRequest(request)
        _       <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        service <- ZIO.service[AuthService]
        _       <- service.updateUser(UUID.fromString(userId), UpdateUserRequest(status = Some("INACTIVE")))
      } yield Response(Status.NoContent)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },

    // POST /api/users/fcm-token — register FCM token
    Method.POST / "api" / "users" / "fcm-token" -> handler { (request: Request) =>
      (for {
        user       <- AuthMiddleware.authenticateRequest(request)
        bodyStr    <- request.body.asString
        tokenReq   <- ZIO
                        .fromEither(bodyStr.fromJson[RegisterFcmTokenRequest])
                        .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        fcmService <- ZIO.service[FcmService]
        _          <- fcmService.registerToken(PersonId(user.userId), tokenReq.token, tokenReq.platform)
      } yield Response(Status.Created)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },

    // DELETE /api/users/fcm-token/{token} — unregister FCM token
    Method.DELETE / "api" / "users" / "fcm-token" / string("token") -> handler { (token: String, request: Request) =>
      (for {
        _          <- AuthMiddleware.authenticateRequest(request)
        fcmService <- ZIO.service[FcmService]
        _          <- fcmService.unregisterToken(token)
      } yield Response(Status.NoContent)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    }
  )
}
