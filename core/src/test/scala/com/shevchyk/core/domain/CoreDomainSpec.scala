package com.shevchyk.core.domain

import zio.test.*
import zio.json.*
import java.util.UUID

object CoreDomainSpec extends ZIOSpecDefault {

  def spec =
    suite("CoreDomain")(
      suite("PersonId")(
        test("should create valid PersonId") {
          val testUuid = UUID.fromString("12345678-1234-1234-1234-123456789012")
          val personId = PersonId(testUuid)
          assertTrue(personId.value == testUuid)
        },
        test("should serialize and deserialize to JSON") {
          val testUuid = UUID.fromString("45678901-2345-2345-2345-456789012345")
          val personId = PersonId(testUuid)
          val json     = personId.toJson
          val decoded  = json.fromJson[PersonId]
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
          val testPersonUuid  = UUID.fromString("12345678-1234-1234-1234-123456789012")
          val testCompanyUuid = UUID.fromString("87654321-4321-4321-4321-210987654321")
          val person          = Person(
            id = PersonId(testPersonUuid),
            name = "John Driver",
            email = "john@example.com",
            role = PersonRole.Driver,
            companyId = Some(CompanyId(testCompanyUuid)),
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
          val clientUuid     = UUID.fromString("11111111-1111-1111-1111-111111111111")
          val driverUuid     = UUID.fromString("22222222-2222-2222-2222-222222222222")
          val dispatcherUuid = UUID.fromString("33333333-3333-3333-3333-333333333333")

          val client     = Person(PersonId(clientUuid), "Client", "client@example.com", PersonRole.Client)
          val driver     = Person(PersonId(driverUuid), "Driver", "driver@example.com", PersonRole.Driver)
          val dispatcher = Person(PersonId(dispatcherUuid), "Dispatcher", "dispatch@example.com", PersonRole.Dispatcher)

          assertTrue(
            client.role == PersonRole.Client &&
              driver.role == PersonRole.Driver &&
              dispatcher.role == PersonRole.Dispatcher
          )
        }
      ),
      suite("Company")(
        test("should create company with valid data") {
          val testCompanyUuid = UUID.fromString("10101010-1010-1010-1010-101010101010")
          val company         = Company(
            id = CompanyId(testCompanyUuid),
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
