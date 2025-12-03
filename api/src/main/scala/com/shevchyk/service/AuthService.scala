package com.shevchyk.service

import com.shevchyk.domain.*
import zio.*
import java.security.MessageDigest
import java.util.UUID
import scala.collection.mutable

trait AuthService:
  def login(request: LoginRequest): Task[Option[LoginResponse]]
  def validateToken(token: String): Task[Option[PersonPublic]]
  def createPerson(person: Person): Task[Person]
  def getAllPersons: Task[List[PersonPublic]]

case class AuthServiceImpl() extends AuthService:

  private def hashPassword(password: String): String =
    val digest = MessageDigest.getInstance("SHA-256")
    digest.digest(password.getBytes("UTF-8")).map("%02x".format(_)).mkString

  private def generateToken(): String = UUID.randomUUID().toString

  override def login(request: LoginRequest): Task[Option[LoginResponse]] = ZIO.succeed {
    AuthService.mockPersons.values
      .find { person =>
        person.email == request.email &&
        person.passwordHash == hashPassword(request.password)
      }
      .map { person =>
        val token     = generateToken()
        val authToken = AuthToken(
          token = token,
          personId = person.id,
          expiresAt = java.lang.System.currentTimeMillis() + (24 * 60 * 60 * 1000) // 24 hours
        )

        // Store token in memory for validation
        AuthService.activeTokens += token -> authToken

        LoginResponse(
          person = PersonPublic(
            id = person.id,
            name = person.name,
            email = person.email,
            role = person.role,
            companyId = person.companyId,
            licenseNumber = person.licenseNumber,
            phone = person.phone
          ),
          token = token
        )
      }
  }

  override def validateToken(token: String): Task[Option[PersonPublic]] = ZIO.succeed {
    AuthService.activeTokens
      .get(token)
      .filter { authToken =>
        authToken.expiresAt > java.lang.System.currentTimeMillis()
      }
      .flatMap { authToken =>
        AuthService.mockPersons.get(authToken.personId).map { person =>
          PersonPublic(
            id = person.id,
            name = person.name,
            email = person.email,
            role = person.role,
            companyId = person.companyId,
            licenseNumber = person.licenseNumber,
            phone = person.phone
          )
        }
      }
  }

  override def createPerson(person: Person): Task[Person] = ZIO.succeed {
    val newPerson = person.copy(id = AuthService.nextId.getAndIncrement())
    AuthService.mockPersons += newPerson.id -> newPerson
    newPerson
  }

  override def getAllPersons: Task[List[PersonPublic]] = ZIO.succeed {
    AuthService.mockPersons.values.map { person =>
      PersonPublic(
        id = person.id,
        name = person.name,
        email = person.email,
        role = person.role,
        companyId = person.companyId,
        licenseNumber = person.licenseNumber,
        phone = person.phone
      )
    }.toList
  }

object AuthService:
  val layer: ZLayer[Any, Nothing, AuthService] = ZLayer.succeed(AuthServiceImpl())

  val nextId       = new java.util.concurrent.atomic.AtomicInteger(5)
  val activeTokens = mutable.Map[String, AuthToken]()

  // Pre-populated test users
  val mockPersons: mutable.Map[Int, Person] = mutable.Map(
    1 -> Person(
      id = 1,
      name = "John Driver",
      email = "driver@test.com",
      role = PersonRole.driver,
      passwordHash = "ecd71870d1963316a97e3ac3408c9835ad8cf0f3c1bc703527c30265534f75ae", // SHA-256 of "test123"
      companyId = Some(1),
      licenseNumber = Some("DL12345"),
      phone = Some("+1234567890")
    ),
    2 -> Person(
      id = 2,
      name = "Anna Client",
      email = "client@test.com",
      role = PersonRole.client,
      passwordHash = "ecd71870d1963316a97e3ac3408c9835ad8cf0f3c1bc703527c30265534f75ae",
      phone = Some("+0987654321")
    ),
    3 -> Person(
      id = 3,
      name = "Maria Secretary",
      email = "secretary@test.com",
      role = PersonRole.secretary,
      passwordHash = "ecd71870d1963316a97e3ac3408c9835ad8cf0f3c1bc703527c30265534f75ae",
      companyId = Some(1)
    ),
    4 -> Person(
      id = 4,
      name = "Peter Dispatcher",
      email = "dispatcher@test.com",
      role = PersonRole.dispatcher,
      passwordHash = "ecd71870d1963316a97e3ac3408c9835ad8cf0f3c1bc703527c30265534f75ae",
      companyId = Some(1)
    )
  )
