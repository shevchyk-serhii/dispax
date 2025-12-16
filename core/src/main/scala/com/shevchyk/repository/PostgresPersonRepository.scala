package com.shevchyk.repository

import com.shevchyk.core.domain.{Person, PersonId, PersonRole, CompanyId}
import zio.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import cats.effect.IO
import zio.interop.catz.*

final class PostgresPersonRepository(xa: Transactor[Task]) extends PersonRepository {

  // Doobie mappers for custom types
  implicit val personRoleMeta: Meta[PersonRole] =
    Meta[String].imap {
      case "driver"     => PersonRole.Driver
      case "client"     => PersonRole.Client
      case "secretary"  => PersonRole.Secretary
      case "dispatcher" => PersonRole.Dispatcher
    } {
      case PersonRole.Driver     => "driver"
      case PersonRole.Client     => "client"
      case PersonRole.Secretary  => "secretary"
      case PersonRole.Dispatcher => "dispatcher"
    }

  override def create(person: Person): Task[Person] = {
    sql"""
      INSERT INTO persons (name, email, role, company_id, license_number, phone) 
      VALUES (${person.name}, ${person.email}, ${person.role}, ${person.companyId}, ${person.licenseNumber}, ${person.phone})
    """.update
      .withUniqueGeneratedKeys[Long]("id")
      .transact(xa)
      .map(id => person.copy(id = PersonId(id)))
  }

  override def findById(id: PersonId): Task[Option[Person]] = {
    sql"""
      SELECT id, name, email, role, company_id, license_number, phone
      FROM persons 
      WHERE id = ${id.value}
    """
      .query[Person]
      .option
      .transact(xa)
  }

  override def findByEmail(email: String): Task[Option[Person]] = {
    sql"""
      SELECT id, name, email, role, company_id, license_number, phone
      FROM persons 
      WHERE email = $email
    """
      .query[Person]
      .option
      .transact(xa)
  }

  override def findByRole(role: PersonRole): Task[List[Person]] = {
    sql"""
      SELECT id, name, email, role, company_id, license_number, phone
      FROM persons 
      WHERE role = $role
    """
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def findByCompanyId(companyId: CompanyId): Task[List[Person]] = {
    sql"""
      SELECT id, name, email, role, company_id, license_number, phone
      FROM persons 
      WHERE company_id = ${companyId.value}
    """
      .query[Person]
      .to[List]
      .transact(xa)
  }

  override def findAll(): Task[List[Person]] = {
    sql"""
      SELECT id, name, email, role, company_id, license_number, phone
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
          phone = ${person.phone}
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

  // Custom Read instance for Person
  implicit val personRead: Read[Person] =
    Read[(Long, String, String, PersonRole, Option[Long], Option[String], Option[String])].map {
      case (id, name, email, role, companyId, licenseNumber, phone) =>
        Person(
          id = PersonId(id),
          name = name,
          email = email,
          role = role,
          companyId = companyId.map(CompanyId.apply),
          licenseNumber = licenseNumber,
          phone = phone
        )
    }
}
