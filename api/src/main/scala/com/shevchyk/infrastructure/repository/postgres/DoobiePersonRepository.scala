package com.shevchyk.infrastructure.repository.postgres

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

case class DoobiePersonRepository(xa: Transactor[Task]) extends PersonRepository:

  implicit val personRoleMeta: Meta[PersonRole] = Meta[String].timap(s => PersonRole.valueOf(s))(_.toString)

  implicit val personIdMeta: Meta[PersonId] = Meta[Int].timap(PersonId.apply)(_.value)

  implicit val companyIdMeta: Meta[CompanyId] = Meta[Int].timap(CompanyId.apply)(_.value)

  def findById(id: PersonId): IO[RepositoryError, Option[Person]] =
    sql"SELECT id, name, email, role, company_id FROM persons WHERE id = $id"
      .query[Person]
      .option
      .transact(xa)
      .mapError(RepositoryError.DatabaseError.apply)

  def findByEmail(email: String): IO[RepositoryError, Option[Person]] =
    sql"SELECT id, name, email, role, company_id FROM persons WHERE email = $email"
      .query[Person]
      .option
      .transact(xa)
      .mapError(RepositoryError.DatabaseError.apply)

  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Person]] =
    sql"SELECT id, name, email, role, company_id FROM persons WHERE company_id = $companyId ORDER BY name"
      .query[Person]
      .to[List]
      .transact(xa)
      .mapError(RepositoryError.DatabaseError.apply)

  def save(person: Person): IO[RepositoryError, Person] =
    person.id.value match {
      case 0 => insert(person)
      case _ => update(person)
    }

  private def insert(person: Person): IO[RepositoryError, Person] =
    val insertSql =
      sql"""
      INSERT INTO persons (name, email, role, company_id) 
      VALUES (${person.name}, ${person.email}, ${person.role}, ${person.companyId})
      RETURNING id
    """

    insertSql
      .query[Int]
      .unique
      .transact(xa)
      .map(id => person.copy(id = PersonId(id)))
      .mapError(RepositoryError.DatabaseError.apply)

  def findAll(): IO[RepositoryError, List[Person]] =
    sql"SELECT id, name, email, role, company_id FROM persons ORDER BY name"
      .query[Person]
      .to[List]
      .transact(xa)
      .mapError(RepositoryError.DatabaseError.apply)

  def update(person: Person): IO[RepositoryError, Person] =
    val updateSql =
      sql"""
      UPDATE persons SET 
        name = ${person.name}, 
        email = ${person.email}, 
        role = ${person.role}, 
        company_id = ${person.companyId}
      WHERE id = ${person.id}
    """

    updateSql.update.run
      .transact(xa)
      .flatMap {
        case 1 => ZIO.succeed(person)
        case 0 => ZIO.fail(RepositoryError.NotFound(person.id.value.toString))
        case n => ZIO.fail(RepositoryError.DatabaseError(new Exception(s"Update affected $n rows, expected 1")))
      }
      .mapError {
        case e: RepositoryError => e
        case t                  => RepositoryError.DatabaseError(t)
      }

  def delete(id: PersonId): IO[RepositoryError, Boolean] = sql"DELETE FROM persons WHERE id = $id".update.run
    .transact(xa)
    .map(_ > 0)
    .mapError(RepositoryError.DatabaseError.apply)
