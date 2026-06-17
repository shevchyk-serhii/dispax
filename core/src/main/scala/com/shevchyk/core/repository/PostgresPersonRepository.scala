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
      case "super_admin"      => PersonRole.SuperAdmin
    },
    {
      case PersonRole.Driver          => "driver"
      case PersonRole.Client          => "client"
      case PersonRole.Secretary       => "secretary"
      case PersonRole.Dispatcher      => "dispatcher"
      case PersonRole.Admin           => "admin"
      case PersonRole.ClientSecretary => "client_secretary"
      case PersonRole.SuperAdmin      => "super_admin"
    }
  )

  // Meta for the roles array column (person_role[]).
  // We read it as Array[String] and map each element through the same label<->enum
  // function as personRoleMeta. On write we need an explicit ::person_role[] cast;
  // see the sql"..." fragments in create/update below.
  private def roleFromLabel(s: String): PersonRole =
    s match
      case "driver"           => PersonRole.Driver
      case "client"           => PersonRole.Client
      case "secretary"        => PersonRole.Secretary
      case "dispatcher"       => PersonRole.Dispatcher
      case "admin"            => PersonRole.Admin
      case "client_secretary" => PersonRole.ClientSecretary
      case "super_admin"      => PersonRole.SuperAdmin
      case other              => throw new IllegalArgumentException(s"Unknown person_role: $other")

  private def roleToLabel(r: PersonRole): String =
    r match
      case PersonRole.Driver          => "driver"
      case PersonRole.Client          => "client"
      case PersonRole.Secretary       => "secretary"
      case PersonRole.Dispatcher      => "dispatcher"
      case PersonRole.Admin           => "admin"
      case PersonRole.ClientSecretary => "client_secretary"
      case PersonRole.SuperAdmin      => "super_admin"

  implicit val personRoleListMeta: Meta[List[PersonRole]] =
    Meta[Array[String]].imap(arr => arr.toList.map(roleFromLabel))(list => list.map(roleToLabel).toArray)

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
    fr"id, name, email, role, company_id, password_hash, license_number, phone, is_vip, preferred_driver_id, status, last_login_at, client_company_id, reminder_minutes, roles::text[]"

  override def create(person: Person): Task[Person] = {
    val rolesArray = person.effectiveRoles.toList
    sql"""
      INSERT INTO persons (id, name, email, role, company_id, password_hash, license_number, phone, is_vip, preferred_driver_id, status, client_company_id, reminder_minutes, roles)
      VALUES (${person.id.value}, ${person.name}, ${person.email}, ${person.role}, ${person.companyId},
              ${person.passwordHash}, ${person.licenseNumber}, ${person.phone}, ${person.isVip},
              ${person.preferredDriverId.map(_.value)}, ${person.status}, ${person.clientCompanyId.map(
        _.value
      )}, ${person.reminderMinutes}, ${rolesArray}::person_role[])
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

  override def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]] = {
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE id = ${id.value} AND company_id = ${companyId.value}")
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
    // Use ANY(roles) so a person with multiple roles (e.g. dispatcher+driver)
    // is returned when searching for either of their roles.
    val roleLabel = roleToLabel(role)
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE ${roleLabel}::person_role = ANY(roles)")
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]] = {
    // Use ANY(roles) so a dispatcher-driver is returned for both roles.
    val roleLabel = roleToLabel(role)
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE ${roleLabel}::person_role = ANY(roles) AND company_id = ${companyId.value}")
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
    val rolesArray = person.effectiveRoles.toList
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
          reminder_minutes = ${person.reminderMinutes},
          roles = ${rolesArray}::person_role[]
      WHERE id = ${person.id.value} AND company_id IS NOT DISTINCT FROM ${person.companyId}
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
    // Escape LIKE wildcards (\ % _) so user input is matched literally and can't widen
    // the search (e.g. "%" matching every row). Backslash first to avoid double-escaping.
    val escaped       = query.toLowerCase
      .replace("\\", "\\\\")
      .replace("%", "\\%")
      .replace("_", "\\_")
    val searchPattern = s"%$escaped%"
    (fr"SELECT" ++ selectColumns ++ fr"FROM persons WHERE LOWER(name) LIKE $searchPattern ESCAPE '\' OR LOWER(email) LIKE $searchPattern ESCAPE '\'")
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

  override def upsertDriverRow(personId: PersonId): Task[Unit] =
    // Mirror the pattern used by PostgresDriverLocationRepository.updateLocation:
    // insert a drivers row with the company_id drawn from the persons table.
    // Safe to call multiple times — ON CONFLICT DO NOTHING makes it idempotent.
    sql"""
      INSERT INTO drivers (id, status, company_id)
      SELECT ${personId.value}, 'Available', p.company_id
      FROM persons p WHERE p.id = ${personId.value}
      ON CONFLICT (id) DO NOTHING
    """.update.run
      .transact(xa)
      .unit

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
          Int,
          List[PersonRole]
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
            reminderMinutes,
            rolesList
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
          reminderMinutes = reminderMinutes,
          roles = rolesList.toSet
        )
    }
}
