package com.shevchyk.app.routes

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import com.shevchyk.auth.middleware.{AuthMiddleware, AuthenticatedUser, RateLimiter}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.core.domain.{Person, PersonDto, PersonId, PersonRole}
import com.shevchyk.notification.application.FcmService
import com.shevchyk.notification.domain.RegisterFcmTokenRequest
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.RideStatus
import java.util.UUID
import zio.*
import zio.http.*
import zio.json.*

object UserRoutes {

  private case class RideStatsResponse(
      totalRides: Int,
      completedRides: Int,
      inProgressRides: Int,
      requestedRides: Int,
      assignedRides: Int,
      cancelledRides: Int,
      activeDrivers: Int,
      totalClients: Int,
      todayRevenue: BigDecimal,
      monthlyRevenue: BigDecimal,
      avgAssignmentMinutes: Double
  ) derives JsonCodec

  private case class DailyStatsEntry(
      date: String,
      completed: Int,
      cancelled: Int,
      total: Int
  ) derives JsonCodec

  private case class DriverStatsEntry(
      driverId: String,
      driverName: String,
      totalRides: Int,
      completedRides: Int,
      cancelledRides: Int,
      earnings: BigDecimal
  ) derives JsonCodec

  private case class UserStatsResponse(
      total: Int,
      byRole: Map[String, Int]
  ) derives JsonCodec

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

  private def checkRateLimit(request: Request): ZIO[RateLimiter, Response, Unit] =
    for {
      rateLimiter <- ZIO.service[RateLimiter]
      ip           = request.remoteAddress.map(_.toString).getOrElse("unknown")
      allowed     <- rateLimiter.checkRate(ip)
      _           <-
        ZIO.when(!allowed)(
          ZIO.fail(
            Response(
              Status.TooManyRequests,
              body = Body.fromString("""{"error":"Too many requests. Please try again later."}""")
            )
          )
        )
    } yield ()

  val authenticatedRoutes
      : Routes[AuthService & PersonRepository & JwtService & FcmService & RideService & RateLimiter, Response] = Routes(
    // GET /api/stats/rides — real ride statistics (dispatcher, secretary)
    Method.GET / "api" / "stats" / "rides" -> authenticatedHandler[RideService & PersonRepository] { (user, _) =>
      (for {
        _                    <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN", "SECRETARY")
        rideService          <- ZIO.service[RideService]
        personRepo           <- ZIO.service[PersonRepository]
        companyId            <- UuidParser.requireCompanyId(user.companyId)
        statusCounts         <- rideService.getRideCountsByStatus(companyId)
        drivers              <- personRepo.findByRoleAndCompany(PersonRole.Driver, companyId)
        clients              <- personRepo.findByRoleAndCompany(PersonRole.Client, companyId)
        revenue              <- rideService.getTotalRevenue(companyId)
        todayRevenue         <- rideService.getTodayRevenue(companyId)
        avgAssignmentMinutes <- rideService.getAvgAssignmentMinutes(companyId)
        requestedCount        = statusCounts.getOrElse("Requested", 0)
        assignedCount         = statusCounts.getOrElse("Assigned", 0)
        inProgressCount       = statusCounts.getOrElse("InProgress", 0)
        completedCount        = statusCounts.getOrElse("Completed", 0)
        cancelledCount        = statusCounts.getOrElse("Cancelled", 0)
        totalRides            = statusCounts.values.sum
        stats                 = RideStatsResponse(
                                  totalRides = totalRides,
                                  completedRides = completedCount,
                                  inProgressRides = inProgressCount,
                                  requestedRides = requestedCount,
                                  assignedRides = assignedCount,
                                  cancelledRides = cancelledCount,
                                  activeDrivers = drivers.length,
                                  totalClients = clients.length,
                                  todayRevenue = todayRevenue,
                                  monthlyRevenue = revenue,
                                  avgAssignmentMinutes = math.round(avgAssignmentMinutes * 10.0) / 10.0
                                )
      } yield Response.json(stats.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },

    // GET /api/stats/rides/daily — daily ride counts for chart (dispatcher)
    Method.GET / "api" / "stats" / "rides" / "daily" -> authenticatedHandler[RideService] { (user, request) =>
      (for {
        _           <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        rideService <- ZIO.service[RideService]
        days         = request.url.queryParams.queryParam("days").flatMap(_.toIntOption).getOrElse(7).min(365).max(1)
        companyId   <- UuidParser.requireCompanyId(user.companyId)
        rawStats    <- rideService.getDailyStats(companyId, days)
        dailyStats   = rawStats.map { case (date, completed, cancelled, total) =>
                         DailyStatsEntry(date, completed, cancelled, total)
                       }
      } yield Response.json(dailyStats.toJson)).catchAll {
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
        drivers     <- personRepo.findByRoleAndCompany(PersonRole.Driver, companyId)
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
                         DriverStatsEntry(
                           driverId = driver.id.value.toString,
                           driverName = driver.name,
                           totalRides = totalRides,
                           completedRides = completedCount,
                           cancelledRides = cancelledCount,
                           earnings = earnings
                         )
                       }
      } yield Response.json(driverStats.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },

    // PUT /api/users/change-password — change own password (any role)
    Method.PUT / "api" / "users" / "change-password" -> handler { (request: Request) =>
      (for {
        _         <- checkRateLimit(request)
        user      <- AuthMiddleware.authenticateRequest(request)
        bodyStr   <- request.body.asString
        changeReq <- ZIO
                       .fromEither(bodyStr.fromJson[ChangePasswordRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        service   <- ZIO.service[AuthService]
        _         <- service.changePassword(user.userId, changeReq)
      } yield Response(Status.NoContent)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },

    // GET /api/users — list all users (dispatcher/admin)
    Method.GET / "api" / "users" / "drivers"    -> authenticatedHandler[PersonRepository] { (user, _) =>
      (for {
        _          <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN", "DRIVER")
        personRepo <- ZIO.service[PersonRepository]
        companyId  <- UuidParser.requireCompanyId(user.companyId)
        drivers    <- personRepo.findByRoleAndCompany(PersonRole.Driver, companyId)
      } yield Response.json(drivers.map(PersonDto.fromPerson).toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },
    Method.GET / "api" / "users" / "clients"    -> authenticatedHandler[PersonRepository] { (user, _) =>
      (for {
        _          <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN", "SECRETARY")
        personRepo <- ZIO.service[PersonRepository]
        companyId  <- UuidParser.requireCompanyId(user.companyId)
        clients    <- personRepo.findByRoleAndCompany(PersonRole.Client, companyId)
      } yield Response.json(clients.map(PersonDto.fromPerson).toJson)).catchAll {
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
            case Some(u) => ZIO.succeed(Response.json(PersonDto.fromPerson(u).toJson))
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
      } yield Response.json(users.map(PersonDto.fromPerson).toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleAuthError(ex)
      }
    },

    // POST /api/users — create user (dispatcher/admin)
    Method.POST / "api" / "users" -> handler { (request: Request) =>
      (for {
        _         <- checkRateLimit(request)
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "ADMIN")
        bodyStr   <- request.body.asString
        createReq <- ZIO
                       .fromEither(bodyStr.fromJson[CreateUserRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        service   <- ZIO.service[AuthService]
        userDto   <- service.createUser(createReq)
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
        byRole      = all.groupBy(_.role).map((role, persons) => role.toString -> persons.size)
        total       = all.size
        stats       = UserStatsResponse(total = total, byRole = byRole)
      } yield Response.json(stats.toJson)).catchAll {
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
