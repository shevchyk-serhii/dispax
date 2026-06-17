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
        },
        // ── multi-role helpers (dispatcher-can-drive) ─────────────────────
        test("single-role person: effectiveRoles returns Set(role)") {
          val driver = Person(
            PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000001")),
            "Driver",
            "d@x.com",
            PersonRole.Driver
          )
          assertTrue(
            driver.effectiveRoles == Set(PersonRole.Driver) &&
              driver.canDrive &&
              driver.primaryRole == PersonRole.Driver
          )
        },
        test("dispatcher-driver: effectiveRoles always includes primary role") {
          val dispDriver = Person(
            id = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000002")),
            name = "Disp Driver",
            email = "dd@x.com",
            role = PersonRole.Dispatcher,
            roles = Set(PersonRole.Dispatcher, PersonRole.Driver)
          )
          assertTrue(
            dispDriver.effectiveRoles == Set(PersonRole.Dispatcher, PersonRole.Driver) &&
              dispDriver.hasRole(PersonRole.Driver) &&
              dispDriver.hasRole(PersonRole.Dispatcher) &&
              dispDriver.canDrive &&
              dispDriver.primaryRole == PersonRole.Dispatcher
          )
        },
        test("roles=Set.empty falls back to Set(role) via effectiveRoles") {
          val person = Person(
            id = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000003")),
            name = "Test",
            email = "t@x.com",
            role = PersonRole.Client,
            roles = Set.empty
          )
          assertTrue(
            person.effectiveRoles == Set(PersonRole.Client) &&
              !person.canDrive
          )
        },
        test("roles provided without primary: effectiveRoles adds primary automatically") {
          // Even if roles was created without the primary, effectiveRoles forces it in.
          val person = Person(
            id = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000004")),
            name = "Test",
            email = "t2@x.com",
            role = PersonRole.Dispatcher,
            roles = Set(PersonRole.Driver) // primary missing — effectiveRoles must add it
          )
          assertTrue(
            person.effectiveRoles.contains(PersonRole.Dispatcher) &&
              person.effectiveRoles.contains(PersonRole.Driver)
          )
        },
        test("canDrive is false for non-driver roles") {
          val dispatcher = Person(
            id = PersonId(UUID.fromString("aaaaaaaa-0000-0000-0000-000000000005")),
            name = "Disp",
            email = "disp@x.com",
            role = PersonRole.Dispatcher,
            roles = Set(PersonRole.Dispatcher)
          )
          assertTrue(!dispatcher.canDrive)
        }
      ),
      suite("Company")(
        test("should create company with valid data") {
          val testCompanyUuid = UUID.fromString("10101010-1010-1010-1010-101010101010")
          val company         = Company(
            id = CompanyId(testCompanyUuid),
            name = "Dispax Taxi",
            email = "info@dispax.taxi",
            phone = "+380501234567",
            address = "Kyiv, Ukraine"
          )
          assertTrue(
            company.name == "Dispax Taxi" &&
              company.email == "info@dispax.taxi"
          )
        }
      )
    )
}
