package com.shevchyk.repository

import com.shevchyk.core.domain.{Person, PersonId, PersonRole, CompanyId}
import zio.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import cats.effect.IO
import zio.interop.catz.*
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

final class PostgresPersonRepository(xa: Transactor[Task]) extends PersonRepository {

  implicit val personRoleMeta: Meta[PersonRole] = pgEnumString(
    "person_role",
    {
      case "driver"     => PersonRole.Driver
      case "client"     => PersonRole.Client
      case "secretary"  => PersonRole.Secretary
      case "dispatcher" => PersonRole.Dispatcher
    },
    {
      case PersonRole.Driver     => "driver"
      case PersonRole.Client     => "client"
      case PersonRole.Secretary  => "secretary"
      case PersonRole.Dispatcher => "dispatcher"
    }
  )

  override def create(person: Person): Task[Person] = {
    val personWithId =
      if (person.id.value == null)
        person.copy(id = PersonId.generate())
      else
        person
    sql"""
      INSERT INTO persons (id, name, email, role, company_id, license_number, phone, is_vip, preferred_driver_id)
      VALUES (${personWithId.id.value}, ${personWithId.name}, ${personWithId.email}, ${personWithId.role}, ${personWithId.companyId}, ${personWithId.licenseNumber}, ${personWithId.phone}, ${personWithId.isVip}, ${personWithId.preferredDriverId
        .map(_.value)})
    """.update.run
      .transact(xa)
      .as(personWithId)
  }

  override def findById(id: PersonId): Task[Option[Person]] = {
    sql"""
      SELECT id, name, email, role, company_id, license_number, phone, is_vip, preferred_driver_id
      FROM persons
      WHERE id = ${id.value}
    """
      .query[Person]
      .option
      .transact(xa)
  }

  override def findByEmail(email: String): Task[Option[Person]] = {
    sql"""
      SELECT id, name, email, role, company_id, license_number, phone, is_vip, preferred_driver_id
      FROM persons
      WHERE email = $email
    """
      .query[Person]
      .option
      .transact(xa)
  }

  override def findByRole(role: PersonRole): Task[List[Person]] = {
    sql"""
      SELECT id, name, email, role, company_id, license_number, phone, is_vip, preferred_driver_id
      FROM persons
      WHERE role = $role
    """
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def findByCompanyId(companyId: CompanyId): Task[List[Person]] = {
    sql"""
      SELECT id, name, email, role, company_id, license_number, phone, is_vip, preferred_driver_id
      FROM persons
      WHERE company_id = ${companyId.value}
    """
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def findAll(): Task[List[Person]] = {
    sql"""
      SELECT id, name, email, role, company_id, license_number, phone, is_vip, preferred_driver_id
      FROM persons
      ORDER BY id
    """
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
          license_number = ${person.licenseNumber},
          phone = ${person.phone},
          is_vip = ${person.isVip},
          preferred_driver_id = ${person.preferredDriverId.map(_.value)}
      WHERE id = ${person.id.value}
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

  implicit val personRead: Read[Person] =
    Read[(UUID, String, String, PersonRole, Option[UUID], Option[String], Option[String], Boolean, Option[UUID])].map {
      case (id, name, email, role, companyId, licenseNumber, phone, isVip, preferredDriverId) =>
        Person(
          id = PersonId(id),
          name = name,
          email = email,
          role = role,
          companyId = companyId.map(CompanyId.apply),
          licenseNumber = licenseNumber,
          phone = phone,
          isVip = isVip,
          preferredDriverId = preferredDriverId.map(PersonId.apply)
        )
    }
}
