package com.shevchyk.core.domain

import sttp.tapir.Schema
import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

// ID wrappers serialize as a *flat* JSON string (e.g. "uuid"), not as an
// object {"value":"uuid"}. The default `derives JsonCodec` on a single-field
// case class would emit the object form, which the clients don't expect (they
// read ids as plain strings). Provide explicit String<->UUID encoder/decoder
// pairs (separate givens so they resolve when other case classes derive their
// own codecs from these fields).
private def idEncoder[A](unwrap: A => UUID): JsonEncoder[A] = JsonEncoder[String].contramap(a => unwrap(a).toString)

private def idDecoder[A](wrap: UUID => A): JsonDecoder[A] = JsonDecoder[String].mapOrFail(s =>
  scala.util.Try(UUID.fromString(s)).toEither.left.map(_ => s"Invalid UUID: $s").map(wrap)
)

case class PersonId(value: UUID)
case class CompanyId(value: UUID)
case class ClientCompanyId(value: UUID)
case class RideId(value: UUID)
case class TariffId(value: UUID)
case class ScheduleDayId(value: UUID)
case class DriverUnavailabilityId(value: UUID)
case class ExternalDriverId(value: UUID)
case class PartnerCompanyId(value: UUID)
case class RideShareTokenId(value: UUID)

// Codecs live in each companion so they're found via the type's implicit scope
// (no import needed) when other case classes derive their JSON codecs.
object PersonId:
  def generate(): PersonId    = PersonId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[PersonId] = idEncoder(_.value)
  given JsonDecoder[PersonId] = idDecoder(PersonId.apply)
  given Schema[PersonId]      = Schema.derived

object CompanyId:
  def generate(): CompanyId    = CompanyId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[CompanyId] = idEncoder(_.value)
  given JsonDecoder[CompanyId] = idDecoder(CompanyId.apply)
  given Schema[CompanyId]      = Schema.derived

object ClientCompanyId:
  def generate(): ClientCompanyId    = ClientCompanyId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[ClientCompanyId] = idEncoder(_.value)
  given JsonDecoder[ClientCompanyId] = idDecoder(ClientCompanyId.apply)
  given Schema[ClientCompanyId]      = Schema.derived

object RideId:
  def generate(): RideId    = RideId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[RideId] = idEncoder(_.value)
  given JsonDecoder[RideId] = idDecoder(RideId.apply)

object TariffId:
  def generate(): TariffId    = TariffId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[TariffId] = idEncoder(_.value)
  given JsonDecoder[TariffId] = idDecoder(TariffId.apply)

object ScheduleDayId:
  def generate(): ScheduleDayId    = ScheduleDayId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[ScheduleDayId] = idEncoder(_.value)
  given JsonDecoder[ScheduleDayId] = idDecoder(ScheduleDayId.apply)

object DriverUnavailabilityId:
  def generate(): DriverUnavailabilityId    = DriverUnavailabilityId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[DriverUnavailabilityId] = idEncoder(_.value)
  given JsonDecoder[DriverUnavailabilityId] = idDecoder(DriverUnavailabilityId.apply)
  given Schema[DriverUnavailabilityId]      = Schema.derived

object ExternalDriverId:
  def generate(): ExternalDriverId    = ExternalDriverId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[ExternalDriverId] = idEncoder(_.value)
  given JsonDecoder[ExternalDriverId] = idDecoder(ExternalDriverId.apply)
  given Schema[ExternalDriverId]      = Schema.derived

object PartnerCompanyId:
  def generate(): PartnerCompanyId    = PartnerCompanyId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[PartnerCompanyId] = idEncoder(_.value)
  given JsonDecoder[PartnerCompanyId] = idDecoder(PartnerCompanyId.apply)
  given Schema[PartnerCompanyId]      = Schema.derived

object RideShareTokenId:
  def generate(): RideShareTokenId    = RideShareTokenId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[RideShareTokenId] = idEncoder(_.value)
  given JsonDecoder[RideShareTokenId] = idDecoder(RideShareTokenId.apply)
  given Schema[RideShareTokenId]      = Schema.derived

final case class Location(
    address: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None
) derives JsonCodec:
  def display: String = address

object Location:
  def apply(address: String): Location = Location(address, None, None)

enum PersonRole:
  case Driver, Client, Secretary, Dispatcher, Admin, ClientSecretary, SuperAdmin

object PersonRole:

  given Schema[PersonRole] = Schema.derivedEnumeration[PersonRole].defaultStringBased

  /**
   * Canonical wire representation of a role (SCREAMING_SNAKE_CASE). Single source of truth shared by the JSON encoder
   * and any place that needs the role as a plain `String` (e.g. DTO fields typed as `String`). Do NOT use
   * `role.toString.toUpperCase` — for multi-word roles it drops the underscore (`SuperAdmin` -> `SUPERADMIN`).
   */
  def toWire(role: PersonRole): String =
    role match
      case PersonRole.ClientSecretary => "CLIENT_SECRETARY"
      case PersonRole.SuperAdmin      => "SUPER_ADMIN"
      case other                      => other.toString.toUpperCase

  /**
   * Parse a wire-format role string (the SCREAMING_SNAKE_CASE produced by [[toWire]], or the raw enum name) back into a
   * [[PersonRole]]. Returns `None` for unknown values instead of silently collapsing them to a default — callers must
   * decide how to handle an unrecognised role. Recognises both the canonical CLIENT_SECRETARY / SUPER_ADMIN spellings
   * and the enum `.toString` form so the two distinct multi-word roles never collapse into Client.
   */
  def fromWire(s: String): Option[PersonRole] =
    val normalized =
      s.toUpperCase match
        case "CLIENT"           => "Client"
        case "DRIVER"           => "Driver"
        case "DISPATCHER"       => "Dispatcher"
        case "SECRETARY"        => "Secretary"
        case "ADMIN"            => "Admin"
        case "CLIENT_SECRETARY" => "ClientSecretary"
        case "CLIENTSECRETARY"  => "ClientSecretary"
        case "SUPER_ADMIN"      => "SuperAdmin"
        case "SUPERADMIN"       => "SuperAdmin"
        case _                  => s
    scala.util.Try(PersonRole.valueOf(normalized)).toOption

  given JsonEncoder[PersonRole] = JsonEncoder[String].contramap(toWire)

  given JsonDecoder[PersonRole] = JsonDecoder[String].mapOrFail { s =>
    fromWire(s).toRight(s"Invalid PersonRole: $s")
  }

enum UserStatus derives JsonCodec:
  case ACTIVE, INACTIVE, SUSPENDED

object UserStatus:
  given Schema[UserStatus] = Schema.derivedEnumeration[UserStatus].defaultStringBased

final case class Person(
    id: PersonId,
    name: String,
    email: String,
    role: PersonRole,
    companyId: Option[CompanyId] = None,
    passwordHash: String = "",
    licenseNumber: Option[String] = None,
    phone: Option[String] = None,
    isVip: Boolean = false,
    preferredDriverId: Option[PersonId] = None,
    status: UserStatus = UserStatus.ACTIVE,
    lastLoginAt: Option[Instant] = None,
    clientCompanyId: Option[ClientCompanyId] = None,
    reminderMinutes: Int = 60,
    roles: Set[PersonRole] = Set.empty,
    // avatarPresent is a computed flag populated by selectColumns (avatar IS NOT NULL).
    // The actual bytes are NOT loaded in routine selects — use PersonRepository.getAvatar.
    avatarPresent: Boolean = false,
    // avatar bytes are only populated by PersonRepository.getAvatar, never by selectColumns.
    avatar: Option[Array[Byte]] = None,
    avatarContentType: Option[String] = None,
    // User-selected UI language (en, de, uk); None means use the device/system locale.
    preferredLanguage: Option[String] = None,
    // True when the account was created with a temporary password and the user must change it on first login.
    // Set on creation by a dispatcher/admin and cleared by changePassword.
    mustChangePassword: Boolean = false,
    // True for a lightweight "walk-in / from-chat" client created on the fly to book a ride when no real
    // client is known yet. Such a Person does not log in (synthetic email, placeholder password) and is
    // upgraded in place into a real client later. Excluded from billing until upgraded.
    provisional: Boolean = false
):

  /**
   * The effective set of roles — always includes the primary role.
   */
  def effectiveRoles: Set[PersonRole] = if roles.isEmpty then Set(role) else roles + role

  /**
   * Returns true when the person carries the given role (among any of their roles).
   */
  def hasRole(r: PersonRole): Boolean = effectiveRoles.contains(r)

  /**
   * Convenience: true when the person can act as a Driver.
   */
  def canDrive: Boolean = hasRole(PersonRole.Driver)

  /**
   * Primary role (same as `role`, exposed for symmetry with `roles`).
   */
  def primaryRole: PersonRole = role

object Person:

  /**
   * Placeholder password hash stored on a provisional client. It is never a valid bcrypt hash, so the account can never
   * authenticate — a provisional client is a booking placeholder, not a login.
   */
  val ProvisionalPasswordPlaceholder: String = "provisional-no-login"

  /**
   * Default display name for a provisional client when the operator did not type one. Kept short and neutral; the ride
   * card shows the route instead of this label.
   */
  val ProvisionalDefaultName: String = "Walk-in"

  /**
   * Build a lightweight provisional ("walk-in / from-chat") client. It carries the creator's `companyId` so tenant
   * isolation holds, gets a synthetic unique email (the `persons.email` column is UNIQUE NOT NULL) derived from its own
   * id, and a placeholder password so it can never log in. Pure: no effects — generate it and persist via
   * `PersonRepository.create`.
   */
  def provisionalClient(name: Option[String], phone: Option[String], companyId: CompanyId): Person =
    val id = PersonId.generate()
    Person(
      id = id,
      name = name.map(_.trim).filter(_.nonEmpty).getOrElse(ProvisionalDefaultName),
      email = s"provisional+${id.value}@chat.dispax.local",
      role = PersonRole.Client,
      companyId = Some(companyId),
      passwordHash = ProvisionalPasswordPlaceholder,
      phone = phone.map(_.trim).filter(_.nonEmpty),
      provisional = true
    )

// DTO for safe serialization — excludes passwordHash and avatar bytes
final case class PersonDto(
    id: PersonId,
    name: String,
    email: String,
    role: PersonRole,
    companyId: Option[CompanyId] = None,
    licenseNumber: Option[String] = None,
    phone: Option[String] = None,
    isVip: Boolean = false,
    preferredDriverId: Option[PersonId] = None,
    status: UserStatus = UserStatus.ACTIVE,
    clientCompanyId: Option[ClientCompanyId] = None,
    reminderMinutes: Int = 60,
    roles: Set[PersonRole] = Set.empty,
    // true when the person has a profile photo; raw bytes are served separately via GET /api/users/{id}/avatar
    hasAvatar: Boolean = false,
    // resolved company display name — populated by the profile endpoint only (lookup via CompanyRepository)
    companyName: Option[String] = None,
    // user-selected UI language (en, de, uk); None means use the device/system locale
    preferredLanguage: Option[String] = None,
    // true when the account still has a temporary password (created but not yet activated by first-login change)
    mustChangePassword: Boolean = false
) derives JsonCodec

object PersonDto:

  given Schema[PersonDto] = Schema.derived

  def fromPerson(p: Person): PersonDto = PersonDto(
    id = p.id,
    name = p.name,
    email = p.email,
    role = p.role,
    companyId = p.companyId,
    licenseNumber = p.licenseNumber,
    phone = p.phone,
    isVip = p.isVip,
    preferredDriverId = p.preferredDriverId,
    status = p.status,
    clientCompanyId = p.clientCompanyId,
    reminderMinutes = p.reminderMinutes,
    roles = p.effectiveRoles,
    hasAvatar = p.avatarPresent,
    preferredLanguage = p.preferredLanguage,
    mustChangePassword = p.mustChangePassword
  )

enum CompanyStatus derives JsonCodec:
  case Active, Suspended, Trial, Inactive

object CompanyStatus:
  given Schema[CompanyStatus] = Schema.derivedEnumeration[CompanyStatus].defaultStringBased

enum SubscriptionPlan derives JsonCodec:
  case Free, Starter, Professional, Enterprise

object SubscriptionPlan:
  given Schema[SubscriptionPlan] = Schema.derivedEnumeration[SubscriptionPlan].defaultStringBased

final case class Company(
    id: CompanyId,
    name: String,
    email: String,
    phone: String,
    address: String,
    status: CompanyStatus = CompanyStatus.Active,
    subscriptionPlan: SubscriptionPlan = SubscriptionPlan.Free,
    createdAt: java.time.Instant = java.time.Instant.EPOCH,
    updatedAt: java.time.Instant = java.time.Instant.EPOCH
) derives JsonCodec

final case class ClientCompany(
    id: ClientCompanyId,
    name: String,
    taxiCompanyId: CompanyId,
    email: Option[String] = None,
    phone: Option[String] = None,
    address: Option[String] = None,
    preferredLanguage: Option[String] = None,
    // VAT ID (USt-IdNr.) of the billed company — printed on the invoice (German B2B requirement).
    vatId: Option[String] = None,
    // Airport departure pickup timing overrides (NULL = inherit from company or global default).
    airportBufferMinutes: Option[Int] = None,
    airportCheckInCloseMinutes: Option[Int] = None
) derives JsonCodec

final case class CreateClientCompanyRequest(
    name: String,
    email: Option[String] = None,
    phone: Option[String] = None,
    address: Option[String] = None,
    preferredLanguage: Option[String] = None,
    vatId: Option[String] = None,
    // Airport departure pickup timing overrides (absent = no override; uses company or global default).
    airportBufferMinutes: Option[Int] = None,
    airportCheckInCloseMinutes: Option[Int] = None
) derives JsonCodec

/**
 * PATCH payload for updating a client company. Absent fields are left unchanged (merge-patch semantics).
 */
final case class UpdateClientCompanyRequest(
    name: Option[String] = None,
    email: Option[String] = None,
    phone: Option[String] = None,
    address: Option[String] = None,
    preferredLanguage: Option[String] = None,
    vatId: Option[String] = None,
    // Airport departure pickup timing overrides (absent = leave unchanged).
    airportBufferMinutes: Option[Int] = None,
    airportCheckInCloseMinutes: Option[Int] = None
) derives JsonCodec:

  /**
   * Apply the patch onto an existing ClientCompany. Unset fields keep their current value.
   */
  def applyTo(current: ClientCompany): ClientCompany = current.copy(
    name = name.getOrElse(current.name),
    email = email.orElse(current.email),
    phone = phone.orElse(current.phone),
    address = address.orElse(current.address),
    preferredLanguage = preferredLanguage.orElse(current.preferredLanguage),
    vatId = vatId.orElse(current.vatId),
    airportBufferMinutes = airportBufferMinutes.orElse(current.airportBufferMinutes),
    airportCheckInCloseMinutes = airportCheckInCloseMinutes.orElse(current.airportCheckInCloseMinutes)
  )
