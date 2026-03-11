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
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.{Ride, RideStatus}
import java.time.{Instant, LocalDate, ZoneId}
import java.util.UUID
import zio.*
import zio.http.*
import zio.json.*

object UserRoutes {

  private def handleAuthError(ex: Throwable): UIO[Response] =
    ex match
      case UserNotFound(email)       =>
        val msg = s"User not found: $email"
        ZIO.succeed(Response(Status.NotFound, body = Body.fromString(s"""{"error":"$msg"}""")))
      case UserAlreadyExists(email)  =>
        val msg = s"User already exists: $email"
        ZIO.succeed(Response(Status.Conflict, body = Body.fromString(s"""{"error":"$msg"}""")))
      case InvalidCredentials(_)     =>
        ZIO.succeed(Response(Status.Unauthorized, body = Body.fromString(s"""{"error":"Invalid credentials"}""")))
      case WeakPassword(reason)      =>
        ZIO.succeed(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"$reason"}""")))
      case ValidationError(field, m) =>
        val msg = s"$field: $m"
        ZIO.succeed(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"$msg"}""")))
      case other                     =>
        ZIO
          .logError(s"Unhandled error: ${Option(other.getMessage).getOrElse(other.toString)}")
          .as(
            Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
          )

  val routes: Routes[Any, Nothing] = Routes.empty

  val authenticatedRoutes: Routes[AuthService & PersonRepository & JwtService & FcmService & RideService, Response] =
    Routes(
      // GET /api/stats/rides — real ride statistics (dispatcher)
      Method.GET / "api" / "stats" / "rides" -> authenticatedHandler[RideService & PersonRepository] { (user, _) =>
        (for {
          _                   <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
          rideService         <- ZIO.service[RideService]
          personRepo          <- ZIO.service[PersonRepository]
          requested           <- rideService.getRidesByStatus(RideStatus.Requested)
          assigned            <- rideService.getRidesByStatus(RideStatus.Assigned)
          inProgress          <- rideService.getRidesByStatus(RideStatus.InProgress)
          completed           <- rideService.getRidesByStatus(RideStatus.Completed)
          cancelled           <- rideService.getRidesByStatus(RideStatus.Cancelled)
          drivers             <- personRepo.findByRole(PersonRole.Driver)
          clients             <- personRepo.findByRole(PersonRole.Client)
          totalRides           = requested.length + assigned.length + inProgress.length + completed.length + cancelled.length
          revenue              = completed.map(r => r.finalPrice.orElse(r.estimatedPrice).getOrElse(BigDecimal(0))).sum
          today                = LocalDate.now()
          todayRevenue         =
            completed
              .filter(r => r.endTime.exists(t => t.atZone(ZoneId.systemDefault()).toLocalDate == today))
              .map(r => r.finalPrice.orElse(r.estimatedPrice).getOrElse(BigDecimal(0)))
              .sum
          ridesWithAssignment  = (assigned ++ inProgress ++ completed).filter(_.startTime.isDefined)
          avgAssignmentMillis  =
            if ridesWithAssignment.nonEmpty then
              ridesWithAssignment
                .map(r => java.time.Duration.between(r.requestTime, r.startTime.get).toMillis)
                .sum
                .toDouble / ridesWithAssignment.length
            else 0.0
          avgAssignmentMinutes = avgAssignmentMillis / 60000.0
          statsJson            =
            s"""{
          "totalRides": $totalRides,
          "completedRides": ${completed.length},
          "inProgressRides": ${inProgress.length},
          "requestedRides": ${requested.length},
          "assignedRides": ${assigned.length},
          "cancelledRides": ${cancelled.length},
          "activeDrivers": ${drivers.length},
          "totalClients": ${clients.length},
          "todayRevenue": $todayRevenue,
          "monthlyRevenue": $revenue,
          "avgAssignmentMinutes": ${"%.1f".format(avgAssignmentMinutes)}
        }"""
        } yield Response.json(statsJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleAuthError(ex)
        }
      },

      // GET /api/stats/rides/daily — daily ride counts for chart (dispatcher)
      Method.GET / "api" / "stats" / "rides" / "daily" -> authenticatedHandler[RideService] { (user, request) =>
        (for {
          _           <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
          rideService <- ZIO.service[RideService]
          days         = request.url.queryParams.queryParam("days").flatMap(_.toIntOption).getOrElse(7)
          allRides    <- rideService.getAllRides
          today        = LocalDate.now()
          dailyStats   = (0 until days).map { offset =>
                           val date           = today.minusDays(offset.toLong)
                           val dayRides       = allRides.filter { r =>
                             val rideDate = r.requestTime.atZone(ZoneId.systemDefault()).toLocalDate
                             rideDate == date
                           }
                           val completedCount = dayRides.count(_.status == RideStatus.Completed)
                           val cancelledCount = dayRides.count(_.status == RideStatus.Cancelled)
                           val totalCount     = dayRides.length
                           s"""{"date":"$date","completed":$completedCount,"cancelled":$cancelledCount,"total":$totalCount}"""
                         }
          json         = dailyStats.mkString("[", ",", "]")
        } yield Response.json(json)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleAuthError(ex)
        }
      },

      // PUT /api/users/change-password — change own password (any role)
      Method.PUT / "api" / "users" / "change-password" -> authenticatedJsonHandler[AuthService, ChangePasswordRequest] {
        (user, changeReq) =>
          (for {
            service <- ZIO.service[AuthService]
            _       <- service.changePassword(user.userId, changeReq)
          } yield Response(Status.NoContent)).catchAll {
            case response: Response => ZIO.succeed(response)
            case ex: Throwable      => handleAuthError(ex)
          }
      },

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
