package com.shevchyk.auth.domain

import com.shevchyk.core.domain.{Person, PersonRole}
import zio.json.*
import java.util.UUID

case class LoginRequest(
    email: String,
    password: String
) derives JsonCodec

case class LoginResponse(
    person: UserDto,
    token: String
) derives JsonCodec

case class UserDto(
    id: UUID,
    email: String,
    name: String,
    role: String,
    phone: Option[String] = None,
    status: Option[String] = None,
    companyId: Option[UUID] = None,
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

sealed trait AuthError                                     extends Throwable
case class UserNotFound(email: String)                     extends AuthError
case class InvalidCredentials(email: String)               extends AuthError
case class UserAlreadyExists(email: String)                extends AuthError
case class InvalidToken(token: String)                     extends AuthError
case class WeakPassword(reason: String)                    extends AuthError
case class ValidationError(field: String, message: String) extends AuthError

sealed trait JwtError                                  extends AuthError
case class JwtGenerationError(message: String)         extends JwtError
case class InvalidTokenError(message: String)          extends JwtError
case class ExpiredTokenError(message: String)          extends JwtError
case class InvalidPayloadError(message: String)        extends JwtError
case class TokenNotEligibleForRefresh(message: String) extends JwtError

object UserDto:

  def fromPerson(person: Person): UserDto = UserDto(
    id = person.id.value,
    email = person.email,
    name = person.name,
    role = person.role.toString.toUpperCase,
    phone = person.phone,
    status = Some(person.status.toString),
    companyId = person.companyId.map(_.value)
  )
