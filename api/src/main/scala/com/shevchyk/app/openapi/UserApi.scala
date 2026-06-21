package com.shevchyk.app.openapi

import com.shevchyk.auth.application.AuthService
import com.shevchyk.auth.domain.*
import com.shevchyk.auth.middleware.{AuthenticatedUser, RateLimiter}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.application.{AvatarError, AvatarService}
import com.shevchyk.core.domain.{PersonDto, PersonId, PersonRole}
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.notification.application.FcmService
import com.shevchyk.notification.domain.RegisterFcmTokenRequest
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.RideStatus
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*
import java.util.UUID

/**
 * Tapir descriptions and server logic for the user management and statistics endpoints. These replace the hand-written
 * zio-http handlers in `UserRoutes` while keeping the exact same paths, request/response shapes, status codes, role
 * checks and company isolation. The same `ServerEndpoint`s drive both the OpenAPI document and the running server.
 */
object UserApi:

  import ApiSchemas.given

  private val usersTag = "Users"
  private val statsTag = "Statistics"

  // -- Response / request DTOs (lifted from UserRoutes) ---------------------

  final case class RideStatsResponse(
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

  final case class DailyStatsEntry(
      date: String,
      completed: Int,
      cancelled: Int,
      total: Int
  ) derives JsonCodec

  final case class DriverStatsEntry(
      driverId: String,
      driverName: String,
      totalRides: Int,
      completedRides: Int,
      cancelledRides: Int,
      earnings: BigDecimal
  ) derives JsonCodec

  final case class UserStatsResponse(
      total: Int,
      byRole: Map[String, Int]
  ) derives JsonCodec

  final case class ReminderMinutesRequest(minutes: Int) derives JsonCodec

  final case class SuccessResponse(success: Boolean) derives JsonCodec

  final case class AvatarUploadResponse(success: Boolean, avatarUrl: String) derives JsonCodec

  // -- Error helpers --------------------------------------------------------
  //
  // Authenticated endpoints model their error as `(StatusCode, ApiError)` so the
  // server logic can fail with the exact status the original handler produced.
  private type Err = (StatusCode, ApiError)

  private val multiErrorOut = statusCode.and(jsonBody[ApiError])

  private val forbidden: Err    = (StatusCode.Forbidden, ApiError("Insufficient permissions"))
  private val accessDenied: Err = (StatusCode.Forbidden, ApiError("Access denied"))
  private val noCompany: Err    = (StatusCode.BadRequest, ApiError("User must belong to a company"))
  private val notFound: Err     = (StatusCode.NotFound, ApiError("User not found"))
  private val badUuid: Err      = (StatusCode.BadRequest, ApiError("Invalid UUID format"))

  /**
   * Reproduce `AuthMiddleware.checkRole`: fail 403 unless the user has one of the roles.
   */
  private def checkRole(user: AuthenticatedUser, roles: String*): ZIO[Any, Err, Unit] =
    val userRoleUpper = user.role.toUpperCase
    if roles.exists(_.toUpperCase == userRoleUpper) then ZIO.unit
    else ZIO.fail(forbidden)

  /**
   * Reproduce `AuthMiddleware.checkRoleOrOwner`: 403 ("Access denied") unless role or owner.
   */
  private def checkRoleOrOwner(user: AuthenticatedUser, ownerId: UUID, roles: String*): ZIO[Any, Err, Unit] =
    val userRoleUpper = user.role.toUpperCase
    if roles.exists(_.toUpperCase == userRoleUpper) || user.userId == ownerId then ZIO.unit
    else ZIO.fail(accessDenied)

  /**
   * Reproduce `UuidParser.requireCompanyId`.
   */
  private def requireCompanyId(user: AuthenticatedUser): ZIO[Any, Err, com.shevchyk.core.domain.CompanyId] = ZIO
    .fromOption(user.companyId)
    .map(com.shevchyk.core.domain.CompanyId(_))
    .orElseFail(noCompany)

  /**
   * Reproduce `UuidParser.parse`.
   */
  private def parseUuid(value: String): ZIO[Any, Err, UUID] = ZIO.attempt(UUID.fromString(value)).orElseFail(badUuid)

  /**
   * Enforce company isolation for mutate-by-id operations: the target user must belong to the caller's company. Returns
   * 404 ("User not found") otherwise so we don't leak the existence of users in other companies.
   */
  private def requireSameCompany(user: AuthenticatedUser, targetId: UUID): ZIO[PersonRepositoryDep, Err, Unit] =
    for {
      companyId <- requireCompanyId(user)
      repo      <- ZIO.service[PersonRepositoryDep]
      _         <- repo
                     .findByIdAndCompany(PersonId(targetId), companyId)
                     .mapError(internal)
                     .someOrFail((StatusCode.NotFound, ApiError("User not found")))
    } yield ()

  /**
   * Reproduce `UserRoutes.checkRateLimit`: 429 if the per-IP rate limit is exceeded.
   */
  private def checkRateLimit(ip: Option[String]): ZIO[RateLimiter, Err, Unit] =
    val ipKey = ip.getOrElse("unknown")
    for {
      allowed <- ZIO.serviceWithZIO[RateLimiter](_.checkRate(ipKey))
      _       <-
        ZIO.unless(allowed)(
          ZIO.fail((StatusCode.TooManyRequests, ApiError("Too many requests. Please try again later.")))
        )
    } yield ()

  /**
   * Map an `AuthError` to the same status/body `handleAuthError` produced.
   */
  private def mapAuthError(ex: AuthError): Err =
    ex match
      case UserNotFound(_)           => (StatusCode.NotFound, ApiError("User not found"))
      case UserAlreadyExists(_)      => (StatusCode.Conflict, ApiError("User already exists"))
      case InvalidCredentials(_)     => (StatusCode.Unauthorized, ApiError("Invalid credentials"))
      case WeakPassword(reason)      => (StatusCode.BadRequest, ApiError(reason))
      case ValidationError(field, m) => (StatusCode.BadRequest, ApiError(s"$field: $m"))
      case _                         => (StatusCode.InternalServerError, ApiError("Internal server error"))

  // -- Environment ----------------------------------------------------------
  //
  // All server endpoints share one environment (incl. JwtService from the secure
  // security logic) so they can be interpreted together.
  type UserEnv                      =
    JwtService & AuthService & PersonRepositoryDep & FcmService & RideService & RateLimiter & AvatarService &
      CompanyRepositoryDep
  // PersonRepository lives in core; alias keeps the type readable.
  private type PersonRepositoryDep  = com.shevchyk.core.repository.PersonRepository
  // CompanyRepository lives in core; used by the profile endpoint to resolve the company name.
  private type CompanyRepositoryDep = com.shevchyk.core.repository.CompanyRepository

  // -- Authenticated base ---------------------------------------------------
  //
  // Like `secureBase`, but the error output is `(StatusCode, ApiError)`
  // so each endpoint's logic can fail with the exact status the original handler produced.
  private def validateBearer(token: String): ZIO[JwtService, Err, AuthenticatedUser] = ZIO
    .serviceWithZIO[JwtService](_.validateToken(token))
    .mapBoth(
      {
        case _: InvalidTokenError | _: ExpiredTokenError =>
          (StatusCode.Unauthorized, ApiError("Invalid or expired token"))
        case _: JwtError                                 => (StatusCode.Unauthorized, ApiError("Authentication failed"))
        case _                                           => (StatusCode.InternalServerError, ApiError("Internal server error"))
      },
      payload =>
        AuthenticatedUser(
          userId = payload.userId,
          email = payload.email,
          role = payload.role.toString,
          companyId = payload.companyId,
          clientCompanyId = payload.clientCompanyId
        )
    )

  private val secureBase = endpoint
    .securityIn(auth.bearer[String]())
    .errorOut(multiErrorOut)
    .zServerSecurityLogic[JwtService, AuthenticatedUser](validateBearer)

  // -- Endpoint descriptions (schema only) ---------------------------------

  // Public stubs (no auth) -------------------------------------------------
  val passwordChangeStubEndpoint = endpoint.post
    .in("api" / "users" / "password" / "change")
    .out(jsonBody[SuccessResponse])
    .tag(usersTag)
    .summary("Change password (stub)")

  // Avatar endpoints (authenticated) ---------------------------------------
  // Use the untyped multipartBody (Seq[Part[Array[Byte]]]) so that Tapir uses
  // MultipartCodec.Default which reads each part as raw bytes (ByteArrayBody).
  // The typed multipartBody[AvatarUploadInput] cannot be used here because
  // `import sttp.tapir.json.zio.*` brings Codec[String, Array[Byte], Json] into
  // scope; via `part` + `listHead` it satisfies the Part[Array[Byte]] candidate
  // BEFORE the binary ByteArrayBody candidate, causing ZIO-JSON to try to parse
  // raw JPEG bytes as a JSON array and fail with 400.
  val uploadAvatarEndpoint = secureBase.post
    .in("api" / "users" / path[String]("id") / "avatar")
    .in(multipartBody)
    .out(jsonBody[AvatarUploadResponse])
    .tag(usersTag)
    .summary("Upload or replace profile photo")

  val getAvatarEndpoint = secureBase.get
    .in("api" / "users" / path[String]("id") / "avatar")
    .out(byteArrayBody)
    .out(header[String]("Content-Type"))
    .tag(usersTag)
    .summary("Serve profile photo bytes (authenticated, tenant-isolated)")

  val deleteAvatarEndpoint = secureBase.delete
    .in("api" / "users" / path[String]("id") / "avatar")
    .out(statusCode(StatusCode.NoContent))
    .tag(usersTag)
    .summary("Remove profile photo")

  // Authenticated stats ----------------------------------------------------
  val statsRidesEndpoint = secureBase.get
    .in("api" / "stats" / "rides")
    .out(jsonBody[RideStatsResponse])
    .tag(statsTag)
    .summary("Ride statistics (dispatcher, admin, secretary)")

  val statsRidesDailyEndpoint = secureBase.get
    .in("api" / "stats" / "rides" / "daily")
    .in(query[Option[Int]]("days"))
    .out(jsonBody[List[DailyStatsEntry]])
    .tag(statsTag)
    .summary("Daily ride counts for charts (dispatcher, admin)")

  val statsDriversEndpoint = secureBase.get
    .in("api" / "stats" / "drivers")
    .out(jsonBody[List[DriverStatsEntry]])
    .tag(statsTag)
    .summary("Per-driver earnings and ride stats (dispatcher, admin)")

  // Authenticated users ----------------------------------------------------
  val changePasswordEndpoint = secureBase.put
    .in("api" / "users" / "change-password")
    .in(jsonBody[ChangePasswordRequest])
    .in(clientIp)
    .out(statusCode(StatusCode.NoContent))
    .tag(usersTag)
    .summary("Change own password")

  val getProfileEndpoint = secureBase.get
    .in("api" / "users" / "profile")
    .out(jsonBody[PersonDto])
    .tag(usersTag)
    .summary("Get own profile")

  val updateProfileEndpoint = secureBase.put
    .in("api" / "users" / "profile")
    .in(jsonBody[UpdateUserRequest])
    .out(jsonBody[UserDto])
    .tag(usersTag)
    .summary("Update own profile")

  val listDriversEndpoint = secureBase.get
    .in("api" / "users" / "drivers")
    .out(jsonBody[List[PersonDto]])
    .tag(usersTag)
    .summary("List drivers (dispatcher, admin, driver)")

  val listClientsEndpoint = secureBase.get
    .in("api" / "users" / "clients")
    .out(jsonBody[List[PersonDto]])
    .tag(usersTag)
    .summary("List clients (dispatcher, admin, secretary, driver)")

  val userStatsEndpoint = secureBase.get
    .in("api" / "users" / "stats")
    .out(jsonBody[UserStatsResponse])
    .tag(usersTag)
    .summary("User counts by role (dispatcher, admin)")

  val reminderMinutesEndpoint = secureBase.put
    .in("api" / "users" / "reminder-minutes")
    .in(jsonBody[ReminderMinutesRequest])
    .out(statusCode(StatusCode.NoContent))
    .tag(usersTag)
    .summary("Save driver's ride reminder setting")

  val registerFcmTokenEndpoint = secureBase.post
    .in("api" / "users" / "fcm-token")
    .in(jsonBody[RegisterFcmTokenRequest])
    .out(statusCode(StatusCode.Created))
    .tag(usersTag)
    .summary("Register an FCM token")

  val unregisterFcmTokenEndpoint = secureBase.delete
    .in("api" / "users" / "fcm-token" / path[String]("token"))
    .out(statusCode(StatusCode.NoContent))
    .tag(usersTag)
    .summary("Unregister an FCM token")

  val listUsersEndpoint = secureBase.get
    .in("api" / "users")
    .out(jsonBody[List[PersonDto]])
    .tag(usersTag)
    .summary("List all users (dispatcher, admin)")

  val createUserEndpoint = secureBase.post
    .in("api" / "users")
    .in(jsonBody[CreateUserRequest])
    .in(clientIp)
    .out(statusCode(StatusCode.Created).and(jsonBody[UserDto]))
    .tag(usersTag)
    .summary("Create a user (dispatcher, admin)")

  val getUserEndpoint = secureBase.get
    .in("api" / "users" / path[String]("id"))
    .out(jsonBody[PersonDto])
    .tag(usersTag)
    .summary("Get a user by id (dispatcher, admin, or self)")

  val updateUserEndpoint = secureBase.put
    .in("api" / "users" / path[String]("id"))
    .in(jsonBody[UpdateUserRequest])
    .out(jsonBody[UserDto])
    .tag(usersTag)
    .summary("Update a user (dispatcher, admin, or self)")

  val deleteUserEndpoint = secureBase.delete
    .in("api" / "users" / path[String]("id"))
    .out(statusCode(StatusCode.NoContent))
    .tag(usersTag)
    .summary("Deactivate a user (dispatcher, admin)")

  val updateUserRoleEndpoint = secureBase.put
    .in("api" / "users" / path[String]("id") / "role")
    .in(jsonBody[UpdateUserRequest])
    .out(jsonBody[UserDto])
    .tag(usersTag)
    .summary("Change a user's role (dispatcher only)")

  val updateUserStatusEndpoint = secureBase.put
    .in("api" / "users" / path[String]("id") / "status")
    .in(jsonBody[UpdateUserRequest])
    .out(jsonBody[UserDto])
    .tag(usersTag)
    .summary("Activate/suspend/deactivate a user (dispatcher only)")

  /**
   * All endpoint descriptions, used to generate the OpenAPI document.
   */
  val endpoints = List(
    passwordChangeStubEndpoint,
    uploadAvatarEndpoint,
    getAvatarEndpoint,
    deleteAvatarEndpoint,
    statsRidesEndpoint,
    statsRidesDailyEndpoint,
    statsDriversEndpoint,
    changePasswordEndpoint,
    getProfileEndpoint,
    updateProfileEndpoint,
    listDriversEndpoint,
    listClientsEndpoint,
    userStatsEndpoint,
    reminderMinutesEndpoint,
    registerFcmTokenEndpoint,
    unregisterFcmTokenEndpoint,
    listUsersEndpoint,
    createUserEndpoint,
    getUserEndpoint,
    updateUserEndpoint,
    deleteUserEndpoint,
    updateUserRoleEndpoint,
    updateUserStatusEndpoint
  )

  // -- Server logic --------------------------------------------------------

  private val passwordChangeStubServer = passwordChangeStubEndpoint.zServerLogic[UserEnv](_ =>
    ZIO.succeed(SuccessResponse(success = true))
  )

  private val uploadAvatarServer: ZServerEndpoint[UserEnv, Any] = uploadAvatarEndpoint.serverLogic[UserEnv] { user =>
    { case (userId, parts) =>
      for {
        uid        <- parseUuid(userId)
        _          <- requireSameCompany(user, uid)
        _          <- checkRoleOrOwner(user, uid, "DISPATCHER", "ADMIN")
        filePart   <- ZIO
                        .fromOption(parts.find(_.name == "file"))
                        .orElseFail((StatusCode.BadRequest, ApiError("Missing 'file' part in multipart body")))
        bytes       = filePart.body
        contentType = filePart.contentType.getOrElse("image/jpeg")
        _          <- ZIO
                        .serviceWithZIO[AvatarService](_.uploadAvatar(PersonId(uid), bytes, contentType))
                        .mapError { case e: AvatarError => (StatusCode.BadRequest, ApiError(e.message)) }
      } yield AvatarUploadResponse(success = true, avatarUrl = s"/api/users/$userId/avatar")
    }
  }

  private val getAvatarServer: ZServerEndpoint[UserEnv, Any] = getAvatarEndpoint.serverLogic[UserEnv] {
    user => userId =>
      for {
        uid    <- parseUuid(userId)
        _      <- requireSameCompany(user, uid)
        result <- ZIO
                    .serviceWithZIO[AvatarService](_.getAvatar(PersonId(uid)))
                    .mapError(internal)
                    .someOrFail((StatusCode.NotFound, ApiError("Avatar not found")))
      } yield (result._1, result._2)
  }

  private val deleteAvatarServer: ZServerEndpoint[UserEnv, Any] = deleteAvatarEndpoint.serverLogic[UserEnv] {
    user => userId =>
      (for {
        uid <- parseUuid(userId)
        _   <- requireSameCompany(user, uid)
        _   <- checkRoleOrOwner(user, uid, "DISPATCHER", "ADMIN")
        _   <- ZIO.serviceWithZIO[AvatarService](_.deleteAvatar(PersonId(uid))).mapError(internal)
      } yield ()).unit
  }

  private val statsRidesServer: ZServerEndpoint[UserEnv, Any] = statsRidesEndpoint.serverLogic[UserEnv] { user => _ =>
    for {
      _                    <- checkRole(user, "DISPATCHER", "ADMIN", "SECRETARY")
      rideService          <- ZIO.service[RideService]
      personRepo           <- ZIO.service[PersonRepositoryDep]
      companyId            <- requireCompanyId(user)
      statusCounts         <- rideService.getRideCountsByStatus(companyId).mapError(internal)
      drivers              <- personRepo.findByRoleAndCompany(PersonRole.Driver, companyId).mapError(internal)
      clients              <- personRepo.findByRoleAndCompany(PersonRole.Client, companyId).mapError(internal)
      revenue              <- rideService.getTotalRevenue(companyId).mapError(internal)
      todayRevenue         <- rideService.getTodayRevenue(companyId).mapError(internal)
      avgAssignmentMinutes <- rideService.getAvgAssignmentMinutes(companyId).mapError(internal)
      requestedCount        = statusCounts.getOrElse("Requested", 0)
      assignedCount         = statusCounts.getOrElse("Assigned", 0)
      inProgressCount       = statusCounts.getOrElse("InProgress", 0)
      completedCount        = statusCounts.getOrElse("Completed", 0)
      cancelledCount        = statusCounts.getOrElse("Cancelled", 0)
      totalRides            = statusCounts.values.sum
    } yield RideStatsResponse(
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
  }

  private val statsRidesDailyServer: ZServerEndpoint[UserEnv, Any] = statsRidesDailyEndpoint.serverLogic[UserEnv] {
    user => daysOpt =>
      for {
        _           <- checkRole(user, "DISPATCHER", "ADMIN")
        rideService <- ZIO.service[RideService]
        days         = daysOpt.getOrElse(7).min(365).max(1)
        companyId   <- requireCompanyId(user)
        rawStats    <- rideService.getDailyStats(companyId, days).mapError(internal)
      } yield rawStats.map { case (date, completed, cancelled, total) =>
        DailyStatsEntry(date, completed, cancelled, total)
      }
  }

  private val statsDriversServer: ZServerEndpoint[UserEnv, Any] = statsDriversEndpoint.serverLogic[UserEnv] {
    user => _ =>
      for {
        _           <- checkRole(user, "DISPATCHER", "ADMIN")
        rideService <- ZIO.service[RideService]
        personRepo  <- ZIO.service[PersonRepositoryDep]
        companyId   <- requireCompanyId(user)
        drivers     <- personRepo.findByRoleAndCompany(PersonRole.Driver, companyId).mapError(internal)
        allRides    <- rideService.getRidesByCompany(companyId).mapError(internal)
      } yield drivers.map { driver =>
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
  }

  private val changePasswordServer: ZServerEndpoint[UserEnv, Any] = changePasswordEndpoint.serverLogic[UserEnv] {
    user =>
      { case (changeReq, ip) =>
        (for {
          _ <- checkRateLimit(ip)
          _ <- ZIO.serviceWithZIO[AuthService](_.changePassword(user.userId, changeReq)).mapError(mapAuthError)
        } yield ()).unit
      }
  }

  private val getProfileServer: ZServerEndpoint[UserEnv, Any] = getProfileEndpoint.serverLogic[UserEnv] { user => _ =>
    for {
      personRepo  <- ZIO.service[PersonRepositoryDep]
      person      <- personRepo.findById(PersonId(user.userId)).mapError(internal).someOrFail(notFound)
      companyRepo <- ZIO.service[CompanyRepositoryDep]
      companyName <- ZIO
                       .foreach(person.companyId)(cid => companyRepo.findById(cid).mapError(internal))
                       .map(_.flatten.map(_.name))
    } yield PersonDto.fromPerson(person).copy(companyName = companyName)
  }

  private val updateProfileServer: ZServerEndpoint[UserEnv, Any] = updateProfileEndpoint.serverLogic[UserEnv] {
    user => updateReq =>
      ZIO
        .serviceWithZIO[AuthService](_.updateUser(user.userId, updateReq))
        .mapError(mapAuthError)
  }

  private val listDriversServer: ZServerEndpoint[UserEnv, Any] = listDriversEndpoint.serverLogic[UserEnv] { user => _ =>
    for {
      _          <- checkRole(user, "DISPATCHER", "ADMIN", "DRIVER")
      personRepo <- ZIO.service[PersonRepositoryDep]
      companyId  <- requireCompanyId(user)
      drivers    <- personRepo.findByRoleAndCompany(PersonRole.Driver, companyId).mapError(internal)
    } yield drivers.map(PersonDto.fromPerson)
  }

  private val listClientsServer: ZServerEndpoint[UserEnv, Any] = listClientsEndpoint.serverLogic[UserEnv] { user => _ =>
    for {
      _          <- checkRole(user, "DISPATCHER", "ADMIN", "SECRETARY", "DRIVER")
      personRepo <- ZIO.service[PersonRepositoryDep]
      companyId  <- requireCompanyId(user)
      clients    <- personRepo.findByRoleAndCompany(PersonRole.Client, companyId).mapError(internal)
    } yield clients.map(PersonDto.fromPerson)
  }

  private val userStatsServer: ZServerEndpoint[UserEnv, Any] = userStatsEndpoint.serverLogic[UserEnv] { user => _ =>
    for {
      _          <- checkRole(user, "DISPATCHER", "ADMIN")
      personRepo <- ZIO.service[PersonRepositoryDep]
      companyId  <- requireCompanyId(user)
      all        <- personRepo.findByCompanyId(companyId).mapError(internal)
      byRole      = all.groupBy(_.role).map((role, persons) => role.toString -> persons.size)
    } yield UserStatsResponse(total = all.size, byRole = byRole)
  }

  private val reminderMinutesServer: ZServerEndpoint[UserEnv, Any] = reminderMinutesEndpoint.serverLogic[UserEnv] {
    user => req =>
      (for {
        _          <- checkRole(user, "DRIVER")
        _          <- ZIO
                        .fail((StatusCode.BadRequest, ApiError("minutes must be 15, 30, 60, or 90")))
                        .unless(Set(15, 30, 60, 90).contains(req.minutes))
        personRepo <- ZIO.service[PersonRepositoryDep]
        person     <- personRepo
                        .findById(PersonId(user.userId))
                        .mapError(internal)
                        .someOrFail(internal(new RuntimeException("User not found")))
        _          <- personRepo.update(person.copy(reminderMinutes = req.minutes)).mapError(internal)
      } yield ()).unit
  }

  private val registerFcmTokenServer: ZServerEndpoint[UserEnv, Any] = registerFcmTokenEndpoint.serverLogic[UserEnv] {
    user => tokenReq =>
      ZIO
        .serviceWithZIO[FcmService](_.registerToken(PersonId(user.userId), tokenReq.token, tokenReq.platform))
        .mapError(internal)
        .unit
  }

  private val unregisterFcmTokenServer: ZServerEndpoint[UserEnv, Any] = unregisterFcmTokenEndpoint
    .serverLogic[UserEnv] { _ => token =>
      ZIO
        .serviceWithZIO[FcmService](_.unregisterToken(token))
        .mapError(internal)
        .unit
    }

  private val listUsersServer: ZServerEndpoint[UserEnv, Any] = listUsersEndpoint.serverLogic[UserEnv] { user => _ =>
    for {
      _          <- checkRole(user, "DISPATCHER", "ADMIN")
      personRepo <- ZIO.service[PersonRepositoryDep]
      companyId  <- requireCompanyId(user)
      users      <- personRepo.findByCompanyId(companyId).mapError(internal)
    } yield users.map(PersonDto.fromPerson)
  }

  private val createUserServer: ZServerEndpoint[UserEnv, Any] = createUserEndpoint.serverLogic[UserEnv] { user =>
    { case (createReq, ip) =>
      for {
        _       <- checkRateLimit(ip)
        _       <- checkRole(user, "DISPATCHER", "ADMIN")
        userDto <- ZIO.serviceWithZIO[AuthService](_.createUser(createReq)).mapError(mapAuthError)
      } yield userDto
    }
  }

  private val getUserServer: ZServerEndpoint[UserEnv, Any] = getUserEndpoint.serverLogic[UserEnv] { user => userId =>
    for {
      uid        <- parseUuid(userId)
      _          <- checkRoleOrOwner(user, uid, "DISPATCHER", "ADMIN")
      companyId  <- requireCompanyId(user)
      personRepo <- ZIO.service[PersonRepositoryDep]
      // Enforce tenant isolation: a user from another company must not be
      // readable even by a dispatcher/admin. Return NotFound (not Forbidden)
      // to avoid leaking the existence of cross-tenant resources. Owner
      // self-access keeps working because the own record carries the caller's
      // own companyId.
      person     <- personRepo
                      .findById(PersonId(uid))
                      .mapError(internal)
                      .map(_.filter(_.companyId.contains(companyId)))
                      .someOrFail(notFound)
    } yield PersonDto.fromPerson(person)
  }

  private val updateUserServer: ZServerEndpoint[UserEnv, Any] = updateUserEndpoint.serverLogic[UserEnv] { user =>
    { case (userId, updateReq) =>
      for {
        uid     <- parseUuid(userId)
        _       <- checkRoleOrOwner(user, uid, "DISPATCHER", "ADMIN")
        _       <- requireSameCompany(user, uid)
        userDto <- ZIO.serviceWithZIO[AuthService](_.updateUser(uid, updateReq)).mapError(mapAuthError)
      } yield userDto
    }
  }

  private val deleteUserServer: ZServerEndpoint[UserEnv, Any] = deleteUserEndpoint.serverLogic[UserEnv] {
    user => userId =>
      (for {
        _   <- checkRole(user, "DISPATCHER", "ADMIN")
        uid <- parseUuid(userId)
        _   <- requireSameCompany(user, uid)
        _   <- ZIO
                 .serviceWithZIO[AuthService](_.updateUser(uid, UpdateUserRequest(status = Some("INACTIVE"))))
                 .mapError(mapAuthError)
      } yield ()).unit
  }

  private val updateUserRoleServer: ZServerEndpoint[UserEnv, Any] = updateUserRoleEndpoint.serverLogic[UserEnv] {
    user =>
      { case (userId, roleReq) =>
        for {
          _       <- checkRole(user, "DISPATCHER")
          uid     <- parseUuid(userId)
          _       <- ZIO
                       .fail(internal(new RuntimeException("Cannot change your own role")))
                       .when(user.userId == uid)
          _       <- requireSameCompany(user, uid)
          userDto <- ZIO
                       .serviceWithZIO[AuthService](_.updateUser(uid, UpdateUserRequest(role = roleReq.role)))
                       .mapError(mapAuthError)
        } yield userDto
      }
  }

  private val updateUserStatusServer: ZServerEndpoint[UserEnv, Any] = updateUserStatusEndpoint.serverLogic[UserEnv] {
    user =>
      { case (userId, statusReq) =>
        for {
          uid     <- parseUuid(userId)
          _       <- checkRole(user, "DISPATCHER")
          _       <- requireSameCompany(user, uid)
          userDto <- ZIO
                       .serviceWithZIO[AuthService](_.updateUser(uid, UpdateUserRequest(status = statusReq.status)))
                       .mapError(mapAuthError)
        } yield userDto
      }
  }

  /**
   * Generic mapping of any throwable to a 500 (matches the `other` branch of `handleAuthError`).
   */
  private def internal(t: Throwable): Err = (StatusCode.InternalServerError, ApiError("Internal server error"))

  /**
   * All server endpoints, interpreted into zio-http Routes by the api module.
   *
   * Order matters: Tapir tries them in sequence, so the literal `users/...` paths must precede the `users/{id}` path
   * matcher, otherwise e.g. `/api/users/profile` would be captured as id="profile".
   */
  val serverEndpoints: List[ZServerEndpoint[UserEnv, Any]] = List(
    // public stubs
    passwordChangeStubServer,
    // stats
    statsRidesDailyServer,
    statsRidesServer,
    statsDriversServer,
    // users — literal sub-paths first
    changePasswordServer,
    getProfileServer,
    updateProfileServer,
    listDriversServer,
    listClientsServer,
    userStatsServer,
    reminderMinutesServer,
    registerFcmTokenServer,
    unregisterFcmTokenServer,
    // users — collection
    listUsersServer,
    createUserServer,
    // users — {id}/avatar (must come before {id} to avoid being captured as id="avatar")
    uploadAvatarServer,
    getAvatarServer,
    deleteAvatarServer,
    // users — {id} (and {id}/role, {id}/status)
    updateUserRoleServer,
    updateUserStatusServer,
    getUserServer,
    updateUserServer,
    deleteUserServer
  )
