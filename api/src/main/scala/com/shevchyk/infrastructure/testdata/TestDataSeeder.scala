package com.shevchyk.infrastructure.testdata

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import com.shevchyk.infrastructure.repository.*
import zio.*
import scala.util.Random

case class TestDataSeeder(
    personRepo: PersonRepository,
    rideRepo: RideRepository,
    tariffRepo: TariffRepository,
    driverRepo: DriverRepository
):

  def seedTestData(config: TestDataConfig = TestDataConfig.default): Task[TestDataResult] =
    for
      _        <- Console.printLine(s"🌱 Seeding test data...")
      companies = TestDataGenerator.generateCompanies(config.companiesCount)

      // Generate tariffs for each company
      _          <-
        ZIO.foreach(companies) { companyId =>
          val tariff = TestDataGenerator.generateTariff()
          tariffRepo.save(tariff, companyId)
        }

      // Generate persons for each company
      allPersons <-
        ZIO.foreach(companies) { companyId =>
          for
            clients     <-
              ZIO.foreach(TestDataGenerator.generatePersons(config.clientsPerCompany, PersonRole.client, companyId)) {
                person =>
                  personRepo.save(person)
              }
            drivers     <-
              ZIO.foreach(TestDataGenerator.generatePersons(config.driversPerCompany, PersonRole.driver, companyId)) {
                person =>
                  personRepo.save(person)
              }
            secretaries <-
              ZIO.foreach(
                TestDataGenerator.generatePersons(config.secretariesPerCompany, PersonRole.secretary, companyId)
              ) { person =>
                personRepo.save(person)
              }
            dispatchers <-
              ZIO.foreach(
                TestDataGenerator.generatePersons(config.dispatchersPerCompany, PersonRole.dispatcher, companyId)
              ) { person =>
                personRepo.save(person)
              }
          yield (clients, drivers, secretaries, dispatchers, companyId)
        }

      // Generate drivers
      allDrivers <- ZIO
                      .foreach(allPersons) { case (clients, drivers, secretaries, dispatchers, companyId) =>
                        ZIO.foreach(drivers) { driverPerson =>
                          val driver = Driver(
                            id = driverPerson.id,
                            name = driverPerson.name,
                            currentLocation = TestDataGenerator.generateLocation(),
                            status = if Random.nextDouble() < 0.7 then DriverStatus.Available else DriverStatus.Busy,
                            companyId = companyId
                          )
                          driverRepo.save(driver).as(driver)
                        }
                      }
                      .map(_.flatten)

      // Generate rides
      allRides   <- ZIO
                      .foreach(allPersons) { case (clients, drivers, secretaries, dispatchers, companyId) =>
                        val creators       = secretaries ++ dispatchers
                        val companyDrivers = allDrivers.filter(_.companyId == companyId)
                        val rides          = TestDataGenerator.generateRides(
                          config.ridesPerCompany,
                          clients,
                          creators,
                          companyDrivers,
                          companyId
                        )
                        ZIO.foreach(rides)(rideRepo.save)
                      }
                      .map(_.flatten)

      result = TestDataResult(
                 companies = companies,
                 persons = allPersons.flatMap { case (clients, drivers, secretaries, dispatchers, _) =>
                   clients ++ drivers ++ secretaries ++ dispatchers
                 },
                 drivers = allDrivers,
                 rides = allRides
               )

      _ <- Console.printLine(s"✅ Successfully seeded:")
      _ <- Console.printLine(s"   • ${result.companies.length} companies")
      _ <- Console.printLine(s"   • ${result.persons.length} persons")
      _ <- Console.printLine(s"   • ${result.drivers.length} drivers")
      _ <- Console.printLine(s"   • ${result.rides.length} rides")
    yield result

  def clearAllData(): Task[Unit] =
    for
      _ <- Console.printLine("🧹 Clearing all test data...")
      // Note: This assumes repositories have clear methods, or we implement them
      _ <- Console.printLine("⚠️  Clear functionality not implemented - restart application or manually clear database")
    yield ()

case class TestDataConfig(
    companiesCount: Int,
    clientsPerCompany: Int,
    driversPerCompany: Int,
    secretariesPerCompany: Int,
    dispatchersPerCompany: Int,
    ridesPerCompany: Int
) derives zio.json.JsonCodec

object TestDataConfig:

  val default = TestDataConfig(
    companiesCount = 3,
    clientsPerCompany = 20,
    driversPerCompany = 10,
    secretariesPerCompany = 3,
    dispatchersPerCompany = 2,
    ridesPerCompany = 50
  )

  val small = TestDataConfig(
    companiesCount = 1,
    clientsPerCompany = 5,
    driversPerCompany = 3,
    secretariesPerCompany = 1,
    dispatchersPerCompany = 1,
    ridesPerCompany = 10
  )

  val large = TestDataConfig(
    companiesCount = 5,
    clientsPerCompany = 50,
    driversPerCompany = 20,
    secretariesPerCompany = 5,
    dispatchersPerCompany = 3,
    ridesPerCompany = 100
  )

case class TestDataResult(
    companies: List[CompanyId],
    persons: List[Person],
    drivers: List[Driver],
    rides: List[Ride]
):

  def summary: String =
    s"""Test Data Summary:
       |• Companies: ${companies.length}
       |• Persons: ${persons.length}
       |  - Clients: ${persons.count(_.role == PersonRole.client)}
       |  - Drivers: ${persons.count(_.role == PersonRole.driver)}
       |  - Secretaries: ${persons.count(_.role == PersonRole.secretary)}
       |  - Dispatchers: ${persons.count(_.role == PersonRole.dispatcher)}
       |• Active Drivers: ${drivers.count(_.status == DriverStatus.Available)}
       |• Rides: ${rides.length}
       |  - Requested: ${rides.count(_.status == RideStatus.Requested)}
       |  - Assigned: ${rides.count(_.status == RideStatus.Assigned)}
       |  - In Progress: ${rides.count(_.status == RideStatus.InProgress)}
       |  - Completed: ${rides.count(_.status == RideStatus.Completed)}
       |  - Airport transfers: ${rides.count(_.isAirportTransfer)}
       |""".stripMargin

object TestDataSeeder:

  val layer: ZLayer[PersonRepository & RideRepository & TariffRepository & DriverRepository, Nothing, TestDataSeeder] =
    ZLayer.fromFunction(TestDataSeeder.apply)
