package com.shevchyk.core.repository

import com.shevchyk.core.domain.{Person, PersonId, PersonRole, CompanyId, ClientCompanyId, UserStatus}
import zio.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import cats.effect.IO
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

final class PostgresPersonRepository(xa: Transactor[Task]) extends PersonRepository {

  implicit val personRoleMeta: Meta[PersonRole] = pgEnumString(
    "person_role",
    {
      case "driver"           => PersonRole.Driver
      case "client"           => PersonRole.Client
      case "secretary"        => PersonRole.Secretary
      case "dispatcher"       => PersonRole.Dispatcher
      case "admin"            => PersonRole.Admin
      case "client_secretary" => PersonRole.ClientSecretary
    },
    {
      case PersonRole.Driver          => "driver"
      case PersonRole.Client          => "client"
      case PersonRole.Secretary       => "secretary"
      case PersonRole.Dispatcher      => "dispatcher"
      case PersonRole.Admin           => "admin"
      case PersonRole.ClientSecretary => "client_secretary"
    }
  )

  implicit val userStatusMeta: Meta[UserStatus] =
    Meta[String].imap {
      case "ACTIVE"    => UserStatus.ACTIVE
      case "INACTIVE"  => UserStatus.INACTIVE
      case "SUSPENDED" => UserStatus.SUSPENDED
    } {
      case UserStatus.ACTIVE    => "ACTIVE"
      case UserStatus.INACTIVE  => "INACTIVE"
      case UserStatus.SUSPENDED => "SUSPENDED"
    }

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  private val selectColumns =
    fr"id, name, email, role, company_id, password_hash, license_number, phone, is_vip, preferred_driver_id, status, last_login_at, client_company_id, reminder_minutes"

  override def create(person: Person): Task[Person] = {
    sql"""
      INSERT INTO persons (id, name, email, role, company_id, password_hash, license_number, phone, is_vip, preferred_driver_id, status, client_company_id, reminder_minutes)
      VALUES (${person.id.value}, ${person.name}, ${person.email}, ${person.role}, ${person.companyId},
              ${person.passwordHash}, ${person.licenseNumber}, ${person.phone}, ${person.isVip},
              ${person.preferredDriverId.map(_.value)}, ${person.status}, ${person.clientCompanyId.map(
        _.value
      )}, ${person.reminderMinutes})
    """.update.run
      .transact(xa)
      .as(person)
  }

  override def findById(id: PersonId): Task[Option[Person]] = {
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE id = ${id.value}")
      .query[Person]
      .option
      .transact(xa)
  }

  override def findByEmail(email: String): Task[Option[Person]] = {
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE email = $email")
      .query[Person]
      .option
      .transact(xa)
  }

  override def findByRole(role: PersonRole): Task[List[Person]] = {
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE role = $role")
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = {
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE role = $role AND company_id = ${companyId.value}")
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def findByCompanyId(companyId: CompanyId): Task[List[Person]] = {
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE company_id = ${companyId.value}")
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def findAll(): Task[List[Person]] = {
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons ORDER BY id")
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def update(person: Person): Task[Person] = {
    sql"""
      UPDATE persons
      SET name = ${person.name},
          email = ${person.email},
          role = ${person.role},
          company_id = ${person.companyId},
          password_hash = ${person.passwordHash},
          license_number = ${person.licenseNumber},
          phone = ${person.phone},
          is_vip = ${person.isVip},
          preferred_driver_id = ${person.preferredDriverId.map(_.value)},
          status = ${person.status},
          client_company_id = ${person.clientCompanyId.map(_.value)},
          reminder_minutes = ${person.reminderMinutes}
      WHERE id = ${person.id.value} AND company_id = ${person.companyId}
    """.update.run
      .transact(xa)
      .as(person)
  }

  override def delete(id: PersonId): Task[Unit] = {
    sql"""
      DELETE FROM persons WHERE id = ${id.value}
    """.update.run
      .transact(xa)
      .unit
  }

  override def findByStatus(status: UserStatus): Task[List[Person]] = {
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE status = $status")
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def searchByQuery(query: String): Task[List[Person]] = {
    val searchPattern = s"%${query.toLowerCase}%"
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE LOWER(name) LIKE $searchPattern OR LOWER(email) LIKE $searchPattern")
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def updateLastLogin(id: PersonId): Task[Unit] = {
    sql"""
      UPDATE persons SET last_login_at = NOW() WHERE id = ${id.value}
    """.update.run
      .transact(xa)
      .unit
  }

  override def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]] = {
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE client_company_id = ${clientCompanyId.value}")
      .query[Person]
      .to[List]
      .transact(xa)
  }

  implicit val personRead: Read[Person] =
    Read[
      (
          UUID,
          String,
          String,
          PersonRole,
          Option[UUID],
          String,
          Option[String],
          Option[String],
          Boolean,
          Option[UUID],
          UserStatus,
          Option[Instant],
          Option[UUID],
          Int
      )
    ].map {
      case (
            id,
            name,
            email,
            role,
            companyId,
            passwordHash,
            licenseNumber,
            phone,
            isVip,
            preferredDriverId,
            status,
            lastLoginAt,
            clientCompanyId,
            reminderMinutes
          ) =>
        Person(
          id = PersonId(id),
          name = name,
          email = email,
          role = role,
          companyId = companyId.map(CompanyId.apply),
          passwordHash = passwordHash,
          licenseNumber = licenseNumber,
          phone = phone,
          isVip = isVip,
          preferredDriverId = preferredDriverId.map(PersonId.apply),
          status = status,
          lastLoginAt = lastLoginAt,
          clientCompanyId = clientCompanyId.map(ClientCompanyId.apply),
          reminderMinutes = reminderMinutes
        )
    }
}
