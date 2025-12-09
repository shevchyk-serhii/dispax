package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*
import zio.test.*
import zio.test.Assertion.*
import java.time.LocalDateTime

object RideCreationServiceSpec extends ZIOSpecDefault:
  
  val mockRideRepo = ZLayer.succeed(TestMocks.MockRideRepository())
  val mockPersonRepo = ZLayer.succeed(TestMocks.MockPersonRepository())  
  val mockTariffRepo = ZLayer.succeed(TestMocks.MockTariffRepository())

  val serviceLayer = mockRideRepo ++ mockPersonRepo ++ mockTariffRepo >>> RideCreationService.layer

  def spec = suite("RideCreationService")(
    
    test("should successfully create a new ride with valid request") {
      val request = CreateRideRequest(
        clientId = PersonId(1),
        creatorId = PersonId(2), 
        from = Location("Airport", Some(50.0), Some(30.0)),
        to = Location("Hotel", Some(50.1), Some(30.1)),
        pickupDateTime = LocalDateTime.now().plusHours(2),
        flightNumber = Some("KL123")
      )

      for
        service <- ZIO.service[RideCreationService]
        result <- service.createRide(request)
      yield assert(result.ride.clientId)(equalTo(request.clientId)) &&
           assert(result.ride.from)(equalTo(request.from)) &&
           assert(result.ride.to)(equalTo(request.to)) &&
           assert(result.ride.status)(equalTo(RideStatus.Requested)) &&
           assert(result.ride.price.isDefined)(isTrue) &&
           assert(result.ride.flightInfo.isDefined)(isTrue) &&
           assert(result.client.id)(equalTo(request.clientId))
    }.provide(serviceLayer),

    test("should create ride without flight info when no flight number provided") {
      val request = CreateRideRequest(
        clientId = PersonId(1),
        creatorId = PersonId(2),
        from = Location("Downtown", Some(50.0), Some(30.0)),
        to = Location("Hotel", Some(50.1), Some(30.1)),
        pickupDateTime = LocalDateTime.now().plusHours(2),
        flightNumber = None
      )

      for
        service <- ZIO.service[RideCreationService] 
        result <- service.createRide(request)
      yield assert(result.ride.flightInfo)(isNone) &&
           assert(result.ride.price.isDefined)(isTrue)
    }.provide(serviceLayer),

    test("should detect airport transfers correctly") {
      val airportRequest = CreateRideRequest(
        clientId = PersonId(1),
        creatorId = PersonId(2),
        from = Location("Munich Airport", Some(48.3), Some(11.7)),
        to = Location("Hotel", Some(48.1), Some(11.5)), 
        pickupDateTime = LocalDateTime.now().plusHours(2)
      )

      for
        service <- ZIO.service[RideCreationService]
        result <- service.createRide(airportRequest)
      yield assert(result.ride.price.get.amount)(isGreaterThan(15.0)) 
    }.provide(serviceLayer),

    test("should fail when client is not found") {
      val request = CreateRideRequest(
        clientId = PersonId(999), 
        creatorId = PersonId(2),
        from = Location("Airport", Some(50.0), Some(30.0)),
        to = Location("Hotel", Some(50.1), Some(30.1)),
        pickupDateTime = LocalDateTime.now().plusHours(2)
      )

      for
        service <- ZIO.service[RideCreationService]
        result <- service.createRide(request).flip
      yield assert(result)(isSubtype[RideError.PersonNotFound](anything))
    }.provide(serviceLayer),

    test("should fail with validation error for past pickup time") {
      val request = CreateRideRequest(
        clientId = PersonId(1),
        creatorId = PersonId(2),
        from = Location("Airport", Some(50.0), Some(30.0)),
        to = Location("Hotel", Some(50.1), Some(30.1)),
        pickupDateTime = LocalDateTime.now().minusHours(1) 
      )

      for
        service <- ZIO.service[RideCreationService]
        result <- service.createRide(request).flip
      yield assert(result)(isSubtype[RideError.ValidationError](anything))
    }.provide(serviceLayer),

    test("should fail when tariff is not found for company") {
      val request = CreateRideRequest(
        clientId = PersonId(5), 
        creatorId = PersonId(2),
        from = Location("Airport", Some(50.0), Some(30.0)),
        to = Location("Hotel", Some(50.1), Some(30.1)),
        pickupDateTime = LocalDateTime.now().plusHours(2)
      )

      for
        service <- ZIO.service[RideCreationService]
        result <- service.createRide(request).flip  
      yield assert(result)(isSubtype[RideError.TariffNotFound](anything))
    }.provide(serviceLayer),

    test("should generate unique ride IDs for concurrent requests") {
      val request = CreateRideRequest(
        clientId = PersonId(1),
        creatorId = PersonId(2),
        from = Location("Airport", Some(50.0), Some(30.0)),
        to = Location("Hotel", Some(50.1), Some(30.1)),
        pickupDateTime = LocalDateTime.now().plusHours(2)
      )

      for
        service <- ZIO.service[RideCreationService]
        results <- ZIO.collectAllPar(List.fill(5)(service.createRide(request)))
        rideIds = results.map(_.ride.id)
      yield assert(rideIds.distinct.size)(equalTo(5)) 
    }.provide(serviceLayer),

    test("should calculate price correctly based on tariff") {
      val request = CreateRideRequest(
        clientId = PersonId(1),
        creatorId = PersonId(2),
        from = Location("Start", Some(50.0), Some(30.0)),
        to = Location("End", Some(50.1), Some(30.1)),
        pickupDateTime = LocalDateTime.now().withHour(14).plusDays(1) // Daytime to avoid night surcharge
      )

      for
        service <- ZIO.service[RideCreationService]
        result <- service.createRide(request)
        expectedBasePrice = 5.0 
        expectedKmPrice = 1.5 * 10.0 
        expectedTotal = expectedBasePrice + expectedKmPrice
      yield assert(result.ride.price.get.amount)(equalTo(expectedTotal)) &&
           assert(result.ride.price.get.currency)(equalTo("USD"))
    }.provide(serviceLayer)
  )


object TestMocks:

  case class MockRideRepository() extends RideRepository:
    private val rides = collection.mutable.Map[RideId, Ride]()

    def save(ride: Ride): IO[RepositoryError, Ride] = 
      ZIO.succeed {
        rides(ride.id) = ride
        ride
      }

    def update(ride: Ride): IO[RepositoryError, Option[Ride]] = 
      ZIO.succeed {
        rides.get(ride.id).map { _ =>
          rides(ride.id) = ride  
          ride
        }
      }

    def findById(id: RideId): IO[RepositoryError, Option[Ride]] = 
      ZIO.succeed(rides.get(id))

    def findByClientId(clientId: PersonId): IO[RepositoryError, List[Ride]] = 
      ZIO.succeed(rides.values.filter(_.clientId == clientId).toList)

    def findByDriverId(driverId: PersonId): IO[RepositoryError, List[Ride]] = 
      ZIO.succeed(rides.values.filter(_.driverId.contains(driverId)).toList)

    def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Ride]] = 
      ZIO.succeed(rides.values.filter(_.companyId == companyId).toList)

    def findByStatus(status: RideStatus): IO[RepositoryError, List[Ride]] = 
      ZIO.succeed(rides.values.filter(_.status == status).toList)
      
    def findAll(): IO[RepositoryError, List[Ride]] = 
      ZIO.succeed(rides.values.toList)
      
    def delete(id: RideId): IO[RepositoryError, Boolean] = 
      ZIO.succeed(rides.remove(id).isDefined)

  case class MockPersonRepository() extends PersonRepository:
    private val people = Map(
      PersonId(1) -> Person(PersonId(1), "Test Client", "client@test.com", PersonRole.client, Some(CompanyId(1))),
      PersonId(2) -> Person(PersonId(2), "Test Dispatcher", "dispatcher@test.com", PersonRole.dispatcher, Some(CompanyId(1))),
      PersonId(5) -> Person(PersonId(5), "Client No Tariff", "client2@test.com", PersonRole.client, Some(CompanyId(99))) 
    )

    def findById(id: PersonId): IO[RepositoryError, Option[Person]] = 
      ZIO.succeed(people.get(id))

    def findByEmail(email: String): IO[RepositoryError, Option[Person]] = 
      ZIO.succeed(people.values.find(_.email == email))
      
    def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Person]] = 
      ZIO.succeed(people.values.filter(_.companyId.contains(companyId)).toList)
      
    def save(person: Person): IO[RepositoryError, Person] = ZIO.succeed(person)

    def findAll(): IO[RepositoryError, List[Person]] =
      ZIO.succeed(people.values.toList)

    def update(person: Person): IO[RepositoryError, Person] =
      if people.contains(person.id) then
        ZIO.succeed(person)
      else
        ZIO.fail(RepositoryError.NotFound(s"Person not found: ${person.id}"))

    def delete(id: PersonId): IO[RepositoryError, Boolean] =
      ZIO.succeed(people.contains(id))

  case class MockTariffRepository() extends TariffRepository:
    private val tariffs = Map(
      CompanyId(1) -> Tariff(
        basePrice = Price(5.0, "USD"),
        pricePerKm = Price(1.5, "USD"), 
        airportSurcharge = Price(5.0, "USD"),
        nightSurcharge = Price(2.0, "USD")
      )
    )

    def findByCompanyId(companyId: CompanyId): IO[RepositoryError, Option[Tariff]] = 
      ZIO.succeed(tariffs.get(companyId))

    def save(tariff: Tariff, companyId: CompanyId): IO[RepositoryError, Unit] = ZIO.unit