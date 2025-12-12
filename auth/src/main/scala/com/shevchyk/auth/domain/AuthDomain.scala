package com.shevchyk.auth.domain

import zio.json.*

// Domain Models
case class User(
    id: Long,
    email: String,
    name: String,
    role: UserRole,
    passwordHash: String,
    phone: Option[String] = None,
    status: UserStatus = UserStatus.ACTIVE,
    createdAt: java.time.Instant,
    updatedAt: Option[java.time.Instant] = None
) derives JsonCodec

enum UserRole derives JsonCodec:
  case CLIENT, DRIVER, DISPATCHER, SECRETARY, ADMIN

enum UserStatus derives JsonCodec:
  case ACTIVE, INACTIVE, SUSPENDED

// DTOs for API
case class LoginRequest(
    email: String,
    password: String
) derives JsonCodec

case class LoginResponse(
    person: UserDto,
    token: String
) derives JsonCodec

case class UserDto(
    id: Long,
    email: String,
    name: String,
    role: String,
    phone: Option[String] = None,
    status: Option[String] = None,
    createdAt: Option[String] = None
) derives JsonCodec

case class CreateUserRequest(
    email: String,
    name: String,
    role: String,
    password: String,
    phone: Option[String] = None
) derives JsonCodec

case class UpdateUserRequest(
    email: Option[String] = None,
    name: Option[String] = None,
    role: Option[String] = None,
    phone: Option[String] = None,
    status: Option[String] = None
) derives JsonCodec

case class ChangePasswordRequest(
    currentPassword: String,
    newPassword: String
) derives JsonCodec

case class BiometricSetupRequest(
    enabled: Boolean,
    deviceId: String
) derives JsonCodec

case class BiometricSetupResponse(
    success: Boolean,
    biometricEnabled: Boolean
) derives JsonCodec

case class TokenValidationResponse(
    valid: Boolean,
    person: Option[UserDto] = None
) derives JsonCodec

case class AuthSuccessResponse(
    success: Boolean,
    message: Option[String] = None
) derives JsonCodec

case class PasswordResetRequest(
    email: String
) derives JsonCodec

// Domain Errors
sealed trait AuthError                                     extends Throwable
case class UserNotFound(email: String)                     extends AuthError
case class InvalidCredentials(email: String)               extends AuthError
case class UserAlreadyExists(email: String)                extends AuthError
case class InvalidToken(token: String)                     extends AuthError
case class WeakPassword(reason: String)                    extends AuthError
case class ValidationError(field: String, message: String) extends AuthError

// Conversion methods
object UserDto:

  def fromDomain(user: User): UserDto = UserDto(
    id = user.id,
    email = user.email,
    name = user.name,
    role = user.role.toString,
    phone = user.phone,
    status = Some(user.status.toString),
    createdAt = Some(user.createdAt.toString)
  )
