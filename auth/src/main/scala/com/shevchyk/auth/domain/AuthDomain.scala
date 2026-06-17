package com.shevchyk.auth.domain

import com.shevchyk.core.domain.{Person, PersonRole, UserStatus}
import sttp.tapir.Schema
import zio.json.*
import java.util.UUID

case class LoginRequest(
    email: String,
    password: String
) derives JsonCodec

object LoginRequest:
  given Schema[LoginRequest] = Schema.derived

case class LoginResponse(
    person: UserDto,
    token: String
) derives JsonCodec

object LoginResponse:
  given Schema[LoginResponse] = Schema.derived

case class UserDto(
    id: UUID,
    email: String,
    name: String,
    role: String,
    phone: Option[String] = None,
    status: Option[String] = None,
    companyId: Option[UUID] = None,
    createdAt: Option[String] = None,
    roles: List[String] = Nil
) derives JsonCodec

case class CreateUserRequest(
    email: String,
    name: String,
    role: String,
    password: String,
    phone: Option[String] = None,
    roles: Option[List[String]] = None
) derives JsonCodec

object CreateUserRequest:
  given Schema[CreateUserRequest] = Schema.derived

case class UpdateUserRequest(
    email: Option[String] = None,
    name: Option[String] = None,
    role: Option[String] = None,
    phone: Option[String] = None,
    status: Option[String] = None,
    roles: Option[List[String]] = None
) derives JsonCodec:

  /**
   * Apply the patch onto an existing person. The `role`, `status` and `roles` fields are passed in already
   * parsed/validated by the caller (they require effectful validation); the remaining fields are merged from this
   * request.
   */
  def applyTo(current: Person, role: PersonRole, status: UserStatus, rolesSet: Set[PersonRole]): Person = current.copy(
    email = email.getOrElse(current.email),
    name = name.getOrElse(current.name),
    role = role,
    phone = phone.orElse(current.phone),
    status = status,
    roles = rolesSet
  )

object UpdateUserRequest:
  given Schema[UpdateUserRequest] = Schema.derived

case class ChangePasswordRequest(
    currentPassword: String,
    newPassword: String
) derives JsonCodec

object ChangePasswordRequest:
  given Schema[ChangePasswordRequest] = Schema.derived

case class BiometricSetupRequest(
    enabled: Boolean,
    deviceId: String
) derives JsonCodec

object BiometricSetupRequest:
  given Schema[BiometricSetupRequest] = Schema.derived

case class BiometricSetupResponse(
    success: Boolean,
    biometricEnabled: Boolean
) derives JsonCodec

object BiometricSetupResponse:
  given Schema[BiometricSetupResponse] = Schema.derived

case class TokenValidationResponse(
    valid: Boolean,
    person: Option[UserDto] = None
) derives JsonCodec

object TokenValidationResponse:
  given Schema[TokenValidationResponse] = Schema.derived

case class AuthSuccessResponse(
    success: Boolean,
    message: Option[String] = None
) derives JsonCodec

object AuthSuccessResponse:
  given Schema[AuthSuccessResponse] = Schema.derived

case class PasswordResetRequest(
    email: String
) derives JsonCodec

object PasswordResetRequest:
  given Schema[PasswordResetRequest] = Schema.derived

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

  given Schema[UserDto] = Schema.derived

  def fromPerson(person: Person): UserDto = UserDto(
    id = person.id.value,
    email = person.email,
    name = person.name,
    role = PersonRole.toWire(person.role),
    phone = person.phone,
    status = Some(person.status.toString),
    companyId = person.companyId.map(_.value),
    roles = person.effectiveRoles.map(PersonRole.toWire).toList
  )
