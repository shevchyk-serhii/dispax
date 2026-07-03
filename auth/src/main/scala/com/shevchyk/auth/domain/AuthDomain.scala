package com.shevchyk.auth.domain

import com.shevchyk.core.domain.{ClientCompanyId, Person, PersonRole, UserStatus}
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
    roles: List[String] = Nil,
    preferredLanguage: Option[String] = None,
    mustChangePassword: Boolean = false,
    // true when the person has a profile photo. Carried on login (and other UserDto
    // responses) so the app bar shows the avatar immediately, not just after a
    // separate /users/profile refresh. Raw bytes are served via GET /api/users/{id}/avatar.
    hasAvatar: Boolean = false,
    // Carried so the client list card keeps the VIP badge and the client-company link
    // after an update — the app replaces the list row with this response.
    isVip: Boolean = false,
    clientCompanyId: Option[UUID] = None
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

// Supported locale codes — must match AppLocalizations.supportedLocales in the Flutter app.
private val supportedLanguageCodes: Set[String] = Set("en", "de", "uk")

case class UpdateUserRequest(
    email: Option[String] = None,
    name: Option[String] = None,
    role: Option[String] = None,
    phone: Option[String] = None,
    status: Option[String] = None,
    roles: Option[List[String]] = None,
    preferredLanguage: Option[String] = None,
    isVip: Option[Boolean] = None,
    // Link to a billing client-company. Tri-state: absent = leave unchanged, "" = clear the
    // link, UUID string = set it (validated against the caller's tenant in AuthService).
    clientCompanyId: Option[String] = None
) derives JsonCodec:

  /**
   * Apply the patch onto an existing person. The `role`, `status`, `roles` and `clientCompanyId` fields are passed in
   * already parsed/validated by the caller (they require effectful validation); the remaining fields are merged from
   * this request. `preferredLanguage` is silently ignored if it is not one of the supported locale codes (en/de/uk) —
   * unknown values are never written to the database.
   */
  def applyTo(
      current: Person,
      role: PersonRole,
      status: UserStatus,
      rolesSet: Set[PersonRole],
      clientCompanyId: Option[ClientCompanyId]
  ): Person =
    val validatedLang = preferredLanguage.filter(supportedLanguageCodes.contains)
    current.copy(
      email = email.getOrElse(current.email),
      name = name.getOrElse(current.name),
      role = role,
      phone = phone.orElse(current.phone),
      status = status,
      roles = rolesSet,
      preferredLanguage = validatedLang.orElse(current.preferredLanguage),
      isVip = isVip.getOrElse(current.isVip),
      clientCompanyId = clientCompanyId
    )

object UpdateUserRequest:
  given Schema[UpdateUserRequest] = Schema.derived

/**
 * Fill in a provisional ("from-chat / walk-in") client and promote it to a real client. All fields are optional — the
 * operator fills in whatever became known after the ride. Applying this clears the `provisional` flag, so the client
 * then behaves like any normal client (appears in billing once `clientCompanyId` is linked).
 */
case class UpgradeProvisionalClientRequest(
    name: Option[String] = None,
    phone: Option[String] = None,
    // Link to a billing client-company so completed rides become invoiceable. Plain UUID string; absent leaves it unset.
    clientCompanyId: Option[String] = None
) derives JsonCodec

object UpgradeProvisionalClientRequest:
  given Schema[UpgradeProvisionalClientRequest] = Schema.derived

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
case class AccessDenied(reason: String)                    extends AuthError

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
    roles = person.effectiveRoles.map(PersonRole.toWire).toList,
    preferredLanguage = person.preferredLanguage,
    mustChangePassword = person.mustChangePassword,
    hasAvatar = person.avatarPresent,
    isVip = person.isVip,
    clientCompanyId = person.clientCompanyId.map(_.value)
  )
