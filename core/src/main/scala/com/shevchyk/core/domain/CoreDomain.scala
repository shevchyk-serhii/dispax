package com.shevchyk.core.domain

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

// Codecs live in each companion so they're found via the type's implicit scope
// (no import needed) when other case classes derive their JSON codecs.
object PersonId:
  def generate(): PersonId    = PersonId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[PersonId] = idEncoder(_.value)
  given JsonDecoder[PersonId] = idDecoder(PersonId.apply)

object CompanyId:
  def generate(): CompanyId    = CompanyId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[CompanyId] = idEncoder(_.value)
  given JsonDecoder[CompanyId] = idDecoder(CompanyId.apply)

object ClientCompanyId:
  def generate(): ClientCompanyId    = ClientCompanyId(UuidCreator.getTimeOrderedEpoch())
  given JsonEncoder[ClientCompanyId] = idEncoder(_.value)
  given JsonDecoder[ClientCompanyId] = idDecoder(ClientCompanyId.apply)

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

final case class Location(
    address: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None
) derives JsonCodec:
  def display: String = address

object Location:
  def apply(address: String): Location = Location(address, None, None)

enum PersonRole:
  case Driver, Client, Secretary, Dispatcher, Admin, ClientSecretary

object PersonRole:

  given JsonEncoder[PersonRole] = JsonEncoder[String].contramap {
    case PersonRole.ClientSecretary => "CLIENT_SECRETARY"
    case other                      => other.toString
  }

  given JsonDecoder[PersonRole] = JsonDecoder[String].mapOrFail { s =>
    val normalized =
      s match
        case "CLIENT"           => "Client"
        case "DRIVER"           => "Driver"
        case "DISPATCHER"       => "Dispatcher"
        case "SECRETARY"        => "Secretary"
        case "ADMIN"            => "Admin"
        case "CLIENT_SECRETARY" => "ClientSecretary"
        case "client_secretary" => "ClientSecretary"
        case other              => other
    scala.util.Try(PersonRole.valueOf(normalized)).toEither.left.map(_ => s"Invalid PersonRole: $s")
  }

enum UserStatus derives JsonCodec:
  case ACTIVE, INACTIVE, SUSPENDED

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
    reminderMinutes: Int = 60
)

// DTO for safe serialization — excludes passwordHash
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
    reminderMinutes: Int = 60
) derives JsonCodec

object PersonDto:

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
    reminderMinutes = p.reminderMinutes
  )

final case class Company(
    id: CompanyId,
    name: String,
    email: String,
    phone: String,
    address: String
) derives JsonCodec

final case class ClientCompany(
    id: ClientCompanyId,
    name: String,
    taxiCompanyId: CompanyId,
    email: Option[String] = None,
    phone: Option[String] = None,
    address: Option[String] = None
) derives JsonCodec

final case class CreateClientCompanyRequest(
    name: String,
    email: Option[String] = None,
    phone: Option[String] = None,
    address: Option[String] = None
) derives JsonCodec
