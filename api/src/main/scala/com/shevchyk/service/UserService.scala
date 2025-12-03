package com.shevchyk.service

import com.shevchyk.domain.Person
import zio.*

trait UserService:
  def getAllUsers: Task[List[Person]]
  def getUserById(id: Long): Task[Option[Person]]
  def createUser(person: Person): Task[Person]

class UserServiceImpl extends UserService:

  private val users = Ref.make(List.empty[Person])

  override def getAllUsers: Task[List[Person]] =
    for
      userRef <- users
      users   <- userRef.get
    yield users

  override def getUserById(id: Long): Task[Option[Person]] =
    for
      userRef <- users
      users   <- userRef.get
    yield users.find(_.id == id)

  override def createUser(person: Person): Task[Person] =
    for
      userRef <- users
      _       <- userRef.update(person :: _)
    yield person

object UserService:
  val live: ULayer[UserService] = ZLayer.succeed(UserServiceImpl())
