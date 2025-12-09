package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*

enum UserError extends Exception:
  case PersonNotFound(id: PersonId)
  case EmailAlreadyExists(email: String)
  case DatabaseError(cause: RepositoryError)
  case InvalidInput(msg: String)

  def message: String =
    this match
      case PersonNotFound(id)        => s"Person not found: $id"
      case EmailAlreadyExists(email) => s"Email already exists: $email"
      case DatabaseError(cause)      => s"Database error: ${cause.message}"
      case InvalidInput(msg)         => s"Invalid input: $msg"

case class UserApplicationService(
    personRepo: PersonRepository
):

  def getAllUsers: IO[UserError, List[Person]] = personRepo
    .findAll()
    .mapError(UserError.DatabaseError.apply)

  def getUserById(id: PersonId): IO[UserError, Person] = personRepo
    .findById(id)
    .mapError(UserError.DatabaseError.apply)
    .someOrFail(UserError.PersonNotFound(id))

  def createUser(person: Person): IO[UserError, Person] =
    for
      existingUser <- personRepo
                        .findByEmail(person.email)
                        .mapError(UserError.DatabaseError.apply)

      _ <-
        ZIO.when(existingUser.isDefined) {
          ZIO.fail(UserError.EmailAlreadyExists(person.email))
        }

      _ <-
        ZIO.when(person.name.trim.isEmpty) {
          ZIO.fail(UserError.InvalidInput("Name cannot be empty"))
        }

      _ <-
        ZIO.when(person.email.trim.isEmpty || !person.email.contains("@")) {
          ZIO.fail(UserError.InvalidInput("Valid email is required"))
        }

      savedUser <- personRepo
                     .save(person)
                     .mapError(UserError.DatabaseError.apply)
    yield savedUser

  def updateUser(id: PersonId, updatedPerson: Person): IO[UserError, Person] =
    for
      existingUser <- getUserById(id)

      userWithId = updatedPerson.copy(id = id)

      updatedUser <- personRepo
                       .update(userWithId)
                       .mapError(UserError.DatabaseError.apply)
    yield updatedUser

  def deleteUser(id: PersonId): IO[UserError, Boolean] =
    for
      _       <- getUserById(id)
      deleted <- personRepo
                   .delete(id)
                   .mapError(UserError.DatabaseError.apply)
    yield deleted

object UserApplicationService:

  val layer: ZLayer[PersonRepository, Nothing, UserApplicationService] = ZLayer.fromFunction(
    UserApplicationService.apply
  )
