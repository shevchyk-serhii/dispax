package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.repository.{PersonRepository, MockPersonRepository}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.repository.InMemoryRideRepository
import zio.test.*
import zio.*
import java.util.UUID

object RideServiceSpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))

  val testDriverId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))
  val testClientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))

  val testDriver = Person(
    id = testDriverId,
    name = "Test Driver",
    email = "driver@example.com",
    role = PersonRole.Driver,
    companyId = Some(testCompanyId)
  )

  val wrongCompanyDriver = Person(
    id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000002")),
    name = "Other Driver",
    email = "other@example.com",
    role = PersonRole.Driver,
    companyId = Some(otherCompanyId)
  )

  val clientPerson = Person(
    id = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000003")),
    name = "Client Person",
    email = "client@example.com",
    role = PersonRole.Client,
    companyId = Some(testCompanyId)
  )

  /** MockPersonRepository that returns specific persons by ID */
  final case class TestPersonRepository(persons: Map[PersonId, Person]) extends PersonRepository {
    override def create(person: Person): Task[Person] = ZIO.succeed(person)
    override def findById(id: PersonId): Task[Option[Person]] = ZIO.succeed(persons.get(id))
    override def findByEmail(email: String): Task[Option[Person]] = ZIO.succeed(persons.values.find(_.email == email))
    override def findByRole(role: PersonRole): Task[List[Person]] = ZIO.succeed(persons.values.filter(_.role == role).toList)
    override def findByCompanyId(companyId: CompanyId): Task[List[Person]] = ZIO.succeed(persons.values.filter(_.companyId.contains(companyId)).toList)
    override def findAll(): Task[List[Person]] = ZIO.succeed(persons.values.toList)
    override def update(person: Person): Task[Person] = ZIO.succeed(person)
    override def delete(id: PersonId): Task[Unit] = ZIO.unit
  }

  val testPersonRepo = TestPersonRepository(Map(
    testDriver.id -> testDriver,
    wrongCompanyDriver.id -> wrongCompanyDriver,
    clientPerson.id -> clientPerson
  ))

  val standardLayers = InMemoryRideRepository.layer ++ ZLayer.succeed[PersonRepository](testPersonRepo) >>> RideService.layer

  def spec = suite("RideService")(
    suite("getRideById")(
      test("should return RideNotFound error for any ID") {
        for {
          service <- ZIO.service[RideService]
          result  <- service.getRideById(RideId(UUID.fromString("0000007b-0000-0000-0000-000000000123"))).exit
        } yield assertTrue(result.isFailure)
      }.provide(
        InMemoryRideRepository.layer,
        ZLayer.succeed[PersonRepository](MockPersonRepository()),
        RideService.layer
      )
    ),

    suite("createRide")(
      test("should create ride with generated ID") {
        val request = CreateRideRequest(
          clientId = testClientId,
          companyId = testCompanyId,
          pickupLocation = Location("Start Point"),
          dropoffLocation = Location("End Point"),
          notes = Some("Test ride")
        )

        for {
          service <- ZIO.service[RideService]
          ride    <- service.createRide(request)
        } yield assertTrue(
          ride.clientId == request.clientId &&
          ride.pickupLocation == request.pickupLocation &&
          ride.dropoffLocation == request.dropoffLocation &&
          ride.notes == request.notes &&
          ride.status == RideStatus.Requested
        )
      }.provide(
        InMemoryRideRepository.layer,
        ZLayer.succeed[PersonRepository](MockPersonRepository()),
        RideService.layer
      ),

      test("should create airport transfer ride") {
        val request = CreateRideRequest(
          clientId = PersonId(UUID.fromString("000000c8-0000-0000-0000-000000000200")),
          companyId = testCompanyId,
          pickupLocation = Location("Airport Terminal 1"),
          dropoffLocation = Location("Hotel"),
          specifics = Some(RideSpecifics.AirportTransfer("KBP", "PS123"))
        )

        for {
          service <- ZIO.service[RideService]
          ride    <- service.createRide(request)
        } yield assertTrue(
          ride.isAirportTransfer &&
          ride.specifics.exists {
            case RideSpecifics.AirportTransfer(code, flight) =>
              code == "KBP" && flight == "PS123"
          }
        )
      }.provide(
        InMemoryRideRepository.layer,
        ZLayer.succeed[PersonRepository](MockPersonRepository()),
        RideService.layer
      )
    ),

    suite("assignDriver")(
      test("happy path: Requested ride + valid driver same company → Assigned") {
        for {
          service <- ZIO.service[RideService]
          ride    <- service.createRide(CreateRideRequest(
                       clientId = testClientId,
                       companyId = testCompanyId,
                       pickupLocation = Location("A"),
                       dropoffLocation = Location("B")
                     ))
          assigned <- service.assignDriver(ride.id, testDriverId)
        } yield assertTrue(
          assigned.status == RideStatus.Assigned &&
          assigned.driverId.contains(testDriverId)
        )
      }.provide(standardLayers),

      test("should fail when ride is not in Requested status") {
        for {
          service  <- ZIO.service[RideService]
          ride     <- service.createRide(CreateRideRequest(
                        clientId = testClientId,
                        companyId = testCompanyId,
                        pickupLocation = Location("A"),
                        dropoffLocation = Location("B")
                      ))
          assigned <- service.assignDriver(ride.id, testDriverId)
          result   <- service.assignDriver(assigned.id, testDriverId).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.InvalidStatusTransition])
          case _                   => false
        })
      }.provide(standardLayers),

      test("should fail when driver not found") {
        val unknownDriverId = PersonId(UUID.fromString("99999999-9999-9999-9999-999999999999"))
        for {
          service <- ZIO.service[RideService]
          ride    <- service.createRide(CreateRideRequest(
                       clientId = testClientId,
                       companyId = testCompanyId,
                       pickupLocation = Location("A"),
                       dropoffLocation = Location("B")
                     ))
          result  <- service.assignDriver(ride.id, unknownDriverId).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[RideError.DriverNotFound])
          case _                   => false
        })
      }.provide(standardLayers),

      test("should fail when driver belongs to different company") {
        for {
          service <- ZIO.service[RideService]
          ride    <- service.createRide(CreateRideRequest(
                       clientId = testClientId,
                       companyId = testCompanyId,
                       pickupLocation = Location("A"),
                       dropoffLocation = Location("B")
                     ))
          result  <- service.assignDriver(ride.id, wrongCompanyDriver.id).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists {
            case RideError.BusinessRuleViolation("company_isolation", _) => true
            case _                                                       => false
          }
          case _ => false
        })
      }.provide(standardLayers),

      test("should fail when person is not a Driver role") {
        for {
          service <- ZIO.service[RideService]
          ride    <- service.createRide(CreateRideRequest(
                       clientId = testClientId,
                       companyId = testCompanyId,
                       pickupLocation = Location("A"),
                       dropoffLocation = Location("B")
                     ))
          result  <- service.assignDriver(ride.id, clientPerson.id).exit
        } yield assertTrue(result match {
          case Exit.Failure(cause) => cause.failureOption.exists {
            case RideError.BusinessRuleViolation("driver_role", _) => true
            case _                                                  => false
          }
          case _ => false
        })
      }.provide(standardLayers)
    )
  )
}