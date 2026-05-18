package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class PersonId(value: UUID) derives JsonCodec
case class CompanyId(value: UUID) derives JsonCodec
case class ClientCompanyId(value: UUID) derives JsonCodec
case class RideId(value: UUID) derives JsonCodec
case class TariffId(value: UUID) derives JsonCodec
case class ScheduleDayId(value: UUID) derives JsonCodec

object PersonId:
  def generate(): PersonId = PersonId(UuidCreator.getTimeOrderedEpoch())

object CompanyId:
  def generate(): CompanyId = CompanyId(UuidCreator.getTimeOrderedEpoch())

object ClientCompanyId:
  def generate(): ClientCompanyId = ClientCompanyId(UuidCreator.getTimeOrderedEpoch())

object RideId:
  def generate(): RideId = RideId(UuidCreator.getTimeOrderedEpoch())

object TariffId:
  def generate(): TariffId = TariffId(UuidCreator.getTimeOrderedEpoch())

object ScheduleDayId:
  def generate(): ScheduleDayId = ScheduleDayId(UuidCreator.getTimeOrderedEpoch())

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
    clientCompanyId: Option[ClientCompanyId] = None
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
    clientCompanyId: Option[ClientCompanyId] = None
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
    clientCompanyId = p.clientCompanyId
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
