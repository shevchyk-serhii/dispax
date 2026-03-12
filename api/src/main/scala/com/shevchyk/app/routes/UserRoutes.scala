package com.shevchyk.app.routes

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import com.shevchyk.auth.middleware.{AuthMiddleware, AuthenticatedUser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.repository.PersonRepository
import com.shevchyk.auth.middleware.UuidParser
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
      case UserNotFound(_)           =>
        ZIO.succeed(Response(Status.NotFound, body = Body.fromString(s"""{"error":"User not found"}""")))
      case UserAlreadyExists(_)      =>
        ZIO.succeed(Response(Status.Conflict, body = Body.fromString(s"""{"error":"Operation failed"}""")))
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
          companyId           <- UuidParser.requireCompanyId(user.companyId)
          allRides            <- rideService.getRidesByCompany(companyId)
          requested            = allRides.filter(_.status == RideStatus.Requested)
          assigned             = allRides.filter(_.status == RideStatus.Assigned)
          inProgress           = allRides.filter(_.status == RideStatus.InProgress)
          completed            = allRides.filter(_.status == RideStatus.Completed)
          cancelled            = allRides.filter(_.status == RideStatus.Cancelled)
          allDrivers          <- personRepo.findByRole(PersonRole.Driver)
          drivers              = allDrivers.filter(_.companyId.contains(companyId))
          allClients          <- personRepo.findByRole(PersonRole.Client)
          clients              = allClients.filter(_.companyId.contains(companyId))
          totalRides           = requested.length + assigned.length + inProgress.length + completed.length + cancelled.length
          revenue              = completed.map(r => r.finalPrice.orElse(r.estimatedPrice).getOrElse(BigDecimal(0))).sum
          today                = LocalDate.now()
          todayRevenue         =
            completed
              .filter(r => r.endTime.exists(t => t.atZone(ZoneId.systemDefault()).toLocalDate == today))
              .map(r => r.finalPrice.orElse(r.estimatedPrice).getOrElse(BigDecimal(0)))
              .sum
          avgAssignmentMillis  =
            val durations = (assigned ++ inProgress ++ completed).flatMap { r =>
              r.startTime.map(st => java.time.Duration.between(r.requestTime, st).toMillis)
            }
            if durations.nonEmpty then durations.sum.toDouble / durations.length
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
          companyId   <- UuidParser.requireCompanyId(user.companyId)
          allRides    <- rideService.getRidesByCompany(companyId)
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

      // GET /api/stats/drivers — per-driver earnings and ride stats (dispatcher)
      Method.GET / "api" / "stats" / "drivers" -> authenticatedHandler[RideService & PersonRepository] { (user, _) =>
        (for {
          _           <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
          rideService <- ZIO.service[RideService]
          personRepo  <- ZIO.service[PersonRepository]
          companyId   <- UuidParser.requireCompanyId(user.companyId)
          allDrivers  <- personRepo.findByRole(PersonRole.Driver)
          drivers      = allDrivers.filter(_.companyId.contains(companyId))
          allRides    <- rideService.getRidesByCompany(companyId)
          driverStats  = drivers.map { driver =>
                           val driverRides    = allRides.filter(_.driverId.contains(driver.id))
                           val completedRides = driverRides.filter(_.status == RideStatus.Completed)
                           val totalRides     = driverRides.length
                           val completedCount = completedRides.length
                           val cancelledCount = driverRides.count(_.status == RideStatus.Cancelled)
                           val earnings       =
                             completedRides
                               .map(r => r.finalPrice.orElse(r.estimatedPrice).getOrElse(BigDecimal(0)))
                               .sum
                           s"""{
                             "driverId":"${driver.id.value}",
                             "driverName":"${driver.name}",
                             "totalRides":$totalRides,
                             "completedRides":$completedCount,
                             "cancelledRides":$cancelledCount,
                             "earnings":$earnings
                           }"""
                         }
          json         = driverStats.mkString("[", ",", "]")
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
          } yield Response(Status.NoContent)).catchAll { ex =>
            handleAuthError(ex)
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
          uid        <- UuidParser.parse(userId)
          _          <- AuthMiddleware.checkRoleOrOwner(user, uid, "DISPATCHER", "ADMIN")
          personRepo <- ZIO.service[PersonRepository]
          userOpt    <- personRepo.findById(PersonId(uid))
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
          companyId  <- UuidParser.requireCompanyId(user.companyId)
          users      <- personRepo.findByCompanyId(companyId)
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
          uid       <- UuidParser.parse(userId)
          _         <- AuthMiddleware.checkRoleOrOwner(user, uid, "DISPATCHER", "ADMIN")
          bodyStr   <- request.body.asString
          updateReq <- ZIO
                         .fromEither(bodyStr.fromJson[UpdateUserRequest])
                         .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          service   <- ZIO.service[AuthService]
          userDto   <- service.updateUser(uid, updateReq)
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
          uid     <- UuidParser.parse(userId)
          service <- ZIO.service[AuthService]
          _       <- service.updateUser(uid, UpdateUserRequest(status = Some("INACTIVE")))
        } yield Response(Status.NoContent)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleAuthError(ex)
        }
      },

      // PUT /api/users/{id}/role — change user role (dispatcher only, cannot change own role)
      Method.PUT / "api" / "users" / string("id") / "role" -> handler { (userId: String, request: Request) =>
        (for {
          user    <- AuthMiddleware.authenticateRequest(request)
          _       <- AuthMiddleware.checkRole(user, "DISPATCHER")
          uid     <- UuidParser.parse(userId)
          _       <- ZIO
                       .fail(new RuntimeException("Cannot change your own role"))
                       .when(user.userId == uid)
          bodyStr <- request.body.asString
          roleReq <- ZIO
                       .fromEither(bodyStr.fromJson[UpdateUserRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          service <- ZIO.service[AuthService]
          userDto <- service.updateUser(uid, UpdateUserRequest(role = roleReq.role))
        } yield Response.json(userDto.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleAuthError(ex)
        }
      },

      // PUT /api/users/{id}/status — activate/suspend/deactivate user (dispatcher)
      Method.PUT / "api" / "users" / string("id") / "status" -> handler { (userId: String, request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
          bodyStr   <- request.body.asString
          statusReq <- ZIO
                         .fromEither(bodyStr.fromJson[UpdateUserRequest])
                         .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          uid       <- UuidParser.parse(userId)
          service   <- ZIO.service[AuthService]
          userDto   <- service.updateUser(uid, UpdateUserRequest(status = statusReq.status))
        } yield Response.json(userDto.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleAuthError(ex)
        }
      },

      // GET /api/users/stats — user counts by role and status (dispatcher)
      Method.GET / "api" / "users" / "stats" -> handler { (request: Request) =>
        (for {
          user       <- AuthMiddleware.authenticateRequest(request)
          _          <- AuthMiddleware.checkRole(user, "DISPATCHER")
          personRepo <- ZIO.service[PersonRepository]
          companyId  <- UuidParser.requireCompanyId(user.companyId)
          all        <- personRepo.findByCompanyId(companyId)
          byRole      = all.groupBy(_.role).map((role, persons) => s""""${role.toString}":${persons.size}""").mkString(",")
          total       = all.size
          statsJson   = s"""{"total":$total,"byRole":{$byRole}}"""
        } yield Response.json(statsJson)).catchAll {
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
