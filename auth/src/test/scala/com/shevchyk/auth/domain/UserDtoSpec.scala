package com.shevchyk.auth.domain

import com.shevchyk.core.domain.{Person, PersonId, PersonRole}
import zio.test.*

import java.util.UUID

/**
 * Unit tests for `UserDto.fromPerson` role encoding. The role on the wire must be the canonical SCREAMING_SNAKE_CASE
 * form (matching `PersonRole.toWire` / the JSON encoder), so that the Flutter client parses multi-word roles correctly.
 * `role.toString.toUpperCase` is wrong for `SuperAdmin` (it yields "SUPERADMIN", dropping the underscore).
 */
object UserDtoSpec extends ZIOSpecDefault:

  private def person(role: PersonRole, avatarPresent: Boolean = false): Person = Person(
    id = PersonId(UUID.randomUUID()),
    name = "n",
    email = "e@e.com",
    role = role,
    avatarPresent = avatarPresent
  )

  def spec =
    suite("UserDto.fromPerson")(
      test("SuperAdmin encodes as SUPER_ADMIN") {
        assertTrue(UserDto.fromPerson(person(PersonRole.SuperAdmin)).role == "SUPER_ADMIN")
      },
      test("ClientSecretary encodes as CLIENT_SECRETARY") {
        assertTrue(UserDto.fromPerson(person(PersonRole.ClientSecretary)).role == "CLIENT_SECRETARY")
      },
      test("single-word roles encode uppercase") {
        assertTrue(
          UserDto.fromPerson(person(PersonRole.Driver)).role == "DRIVER",
          UserDto.fromPerson(person(PersonRole.Admin)).role == "ADMIN"
        )
      },
      // hasAvatar must travel on the login UserDto so the app bar shows the avatar
      // on first render, not only after a separate /users/profile refresh.
      test("hasAvatar is true when the person has a profile photo") {
        assertTrue(UserDto.fromPerson(person(PersonRole.Driver, avatarPresent = true)).hasAvatar)
      },
      test("hasAvatar is false when the person has no profile photo") {
        assertTrue(!UserDto.fromPerson(person(PersonRole.Driver, avatarPresent = false)).hasAvatar)
      }
    )
