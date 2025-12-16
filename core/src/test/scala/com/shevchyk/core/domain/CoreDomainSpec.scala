package com.shevchyk.core.domain

import zio.test.*
import zio.json.*

object CoreDomainSpec extends ZIOSpecDefault {

  def spec = suite("CoreDomain")(
    suite("PersonId")(
      test("should create valid PersonId") {
        val personId = PersonId(123L)
        assertTrue(personId.value == 123L)
      },
      test("should serialize and deserialize to JSON") {
        val personId = PersonId(456L)
        val json = personId.toJson
        val decoded = json.fromJson[PersonId]
        assertTrue(decoded.isRight && decoded.toOption.contains(personId))
      }
    ),

    suite("Location")(
      test("should create location with coordinates") {
        val location = Location("Kyiv, Ukraine", Some(50.4501), Some(30.5234))
        assertTrue(
          location.address == "Kyiv, Ukraine" &&
          location.latitude.contains(50.4501) &&
          location.longitude.contains(30.5234) &&
          location.display == "Kyiv, Ukraine"
        )
      },
      test("should create location from address only") {
        val location = Location("Lviv, Ukraine")
        assertTrue(
          location.address == "Lviv, Ukraine" &&
          location.latitude.isEmpty &&
          location.longitude.isEmpty
        )
      }
    ),

    suite("Person")(
      test("should create person with all fields") {
        val person = Person(
          id = PersonId(1),
          name = "John Driver",
          email = "john@example.com",
          role = PersonRole.Driver,
          companyId = Some(CompanyId(100)),
          licenseNumber = Some("DL123456"),
          phone = Some("+380123456789")
        )
        assertTrue(
          person.name == "John Driver" &&
          person.role == PersonRole.Driver &&
          person.licenseNumber.contains("DL123456")
        )
      },
      test("should handle different roles") {
        val client = Person(PersonId(1), "Client", "client@example.com", PersonRole.Client)
        val driver = Person(PersonId(2), "Driver", "driver@example.com", PersonRole.Driver)
        val dispatcher = Person(PersonId(3), "Dispatcher", "dispatch@example.com", PersonRole.Dispatcher)
        
        assertTrue(
          client.role == PersonRole.Client &&
          driver.role == PersonRole.Driver &&
          dispatcher.role == PersonRole.Dispatcher
        )
      }
    ),

    suite("Company")(
      test("should create company with valid data") {
        val company = Company(
          id = CompanyId(1),
          name = "Oktopus Taxi",
          email = "info@oktopus.taxi",
          phone = "+380501234567",
          address = "Kyiv, Ukraine"
        )
        assertTrue(
          company.name == "Oktopus Taxi" &&
          company.email == "info@oktopus.taxi"
        )
      }
    )
  )
}