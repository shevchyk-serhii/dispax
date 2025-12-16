package com.shevchyk.auth.repository

import com.shevchyk.auth.domain.*
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

final class PostgresUserRepository(xa: Transactor[Task]) extends UserRepository:

  implicit val userRoleMeta: Meta[UserRole] =
    Meta[String].imap {
      case "CLIENT"     => UserRole.CLIENT
      case "DRIVER"     => UserRole.DRIVER
      case "DISPATCHER" => UserRole.DISPATCHER
      case "SECRETARY"  => UserRole.SECRETARY
      case "ADMIN"      => UserRole.ADMIN
    } {
      case UserRole.CLIENT     => "CLIENT"
      case UserRole.DRIVER     => "DRIVER"
      case UserRole.DISPATCHER => "DISPATCHER"
      case UserRole.SECRETARY  => "SECRETARY"
      case UserRole.ADMIN      => "ADMIN"
    }

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

  implicit val userRead: Read[User] =
    Read[(UUID, String, String, UserRole, String, Option[String], UserStatus, Instant, Option[Instant])].map {
      case (id, email, name, role, passwordHash, phone, status, createdAt, updatedAt) =>
        User(id, email, name, role, passwordHash, phone, status, createdAt, updatedAt)
    }

  override def create(user: User): Task[User] =
    val userWithId =
      if (user.id == null)
        user.copy(id = UuidCreator.getTimeOrderedEpoch())
      else
        user
    sql"""
      INSERT INTO users (id, email, name, role, password_hash, phone, status, created_at, updated_at) 
      VALUES (${userWithId.id}, ${userWithId.email}, ${userWithId.name}, ${userWithId.role}, ${userWithId.passwordHash}, ${userWithId.phone}, ${userWithId.status}, ${userWithId.createdAt}, ${userWithId.updatedAt})
    """.update.run
      .transact(xa)
      .map(_ => userWithId)

  override def findById(id: UUID): Task[Option[User]] =
    sql"""
      SELECT id, email, name, role, password_hash, phone, status, created_at, updated_at
      FROM users 
      WHERE id = $id
    """
      .query[User]
      .option
      .transact(xa)

  override def findByEmail(email: String): Task[Option[User]] =
    sql"""
      SELECT id, email, name, role, password_hash, phone, status, created_at, updated_at
      FROM users 
      WHERE email = $email
    """
      .query[User]
      .option
      .transact(xa)

  override def findAll(): Task[List[User]] =
    sql"""
      SELECT id, email, name, role, password_hash, phone, status, created_at, updated_at
      FROM users
      ORDER BY id
    """
      .query[User]
      .to[List]
      .transact(xa)

  override def findByRole(role: UserRole): Task[List[User]] =
    sql"""
      SELECT id, email, name, role, password_hash, phone, status, created_at, updated_at
      FROM users 
      WHERE role = $role
    """
      .query[User]
      .to[List]
      .transact(xa)

  override def findByStatus(status: UserStatus): Task[List[User]] =
    sql"""
      SELECT id, email, name, role, password_hash, phone, status, created_at, updated_at
      FROM users 
      WHERE status = $status
    """
      .query[User]
      .to[List]
      .transact(xa)

  override def update(user: User): Task[User] =
    sql"""
      UPDATE users 
      SET email = ${user.email}, 
          name = ${user.name}, 
          role = ${user.role},
          password_hash = ${user.passwordHash},
          phone = ${user.phone},
          status = ${user.status},
          updated_at = ${user.updatedAt}
      WHERE id = ${user.id}
    """.update.run
      .transact(xa)
      .map(_ => user)

  override def delete(id: UUID): Task[Unit] =
    sql"""
      DELETE FROM users WHERE id = $id
    """.update.run
      .transact(xa)
      .map(_ => ())

  override def searchByQuery(query: String): Task[List[User]] =
    val searchPattern = s"%${query.toLowerCase}%"
    sql"""
      SELECT id, email, name, role, password_hash, phone, status, created_at, updated_at
      FROM users 
      WHERE LOWER(name) LIKE $searchPattern OR LOWER(email) LIKE $searchPattern
    """
      .query[User]
      .to[List]
      .transact(xa)
