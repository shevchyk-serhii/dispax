package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*
import zio.test.*
import zio.test.Assertion.*
import java.time.LocalDateTime
import java.util.UUID

object RideApplicationServiceSpec extends ZIOSpecDefault:
  val mockRideRepo = ZLayer.succeed(MockRideRepository())
  val mockDriverRepo = ZLayer.succeed(MockDriverRepository())
  val mockPersonRepo = ZLayer.succeed(MockPersonRepository())
  val mockTariffRepo = ZLayer.succeed(MockTariffRepository())
  val mockNotificationService = ZLayer.succeed(MockOldNotificationService())
  val mockLocationService = ZLayer.succeed(MockLocationService())
  val mockFlightInfoService = ZLayer.succeed(MockFlightInfoService())

  val serviceLayer = mockRideRepo ++ mockDriverRepo ++ mockPersonRepo ++ mockTariffRepo ++
                    mockNotificationService ++ mockLocationService ++ mockFlightInfoService >>>
                    RideApplicationService.layer

  def spec = suite("RideApplicationService")(
    test("createRide should successfully create a new ride") {
      val request = CreateRideRequest(
        clientId = PersonId(1),
        creatorId = PersonId(2),
        from = Location("Airport", Some(50.0), Some(30.0)),
        to = Location("Hotel", Some(50.1), Some(30.1)),
        pickupDateTime = LocalDateTime.now().plusHours(2),
        flightNumber = Some("KL123")
      )

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.createRide(request)
      yield assert(result.clientId)(equalTo(request.clientId)) &&
           assert(result.from)(equalTo(request.from)) &&
           assert(result.to)(equalTo(request.to)) &&
           assert(result.status)(equalTo(RideStatus.Requested)) &&
           assert(result.price.isDefined)(isTrue) &&
           assert(result.flightInfo.isDefined)(isTrue)
    }.provide(serviceLayer),

    test("createRide should fail when client is not found") {
      val request = CreateRideRequest(
        clientId = PersonId(999),
        creatorId = PersonId(2),
        from = Location("Airport", Some(50.0), Some(30.0)),
        to = Location("Hotel", Some(50.1), Some(30.1)),
        pickupDateTime = LocalDateTime.now().plusHours(2)
      )

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.createRide(request).flip
      yield assert(result)(isSubtype[RideError.PersonNotFound](anything))
    }.provide(serviceLayer),

    test("createRide should fail with validation error for past pickup time") {
      val request = CreateRideRequest(
        clientId = PersonId(1),
        creatorId = PersonId(2),
        from = Location("Airport", Some(50.0), Some(30.0)),
        to = Location("Hotel", Some(50.1), Some(30.1)),
        pickupDateTime = LocalDateTime.now().minusHours(1) 
      )

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.createRide(request).flip
      yield assert(result)(isSubtype[RideError.ValidationError](anything))
    }.provide(serviceLayer),

    test("assignDriverToRide should successfully assign available driver") {
      val rideId = RideId(1L)
      val requesterId = PersonId(4)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.assignDriverToRide(rideId, requesterId)
      yield assert(result.driverId.isDefined)(isTrue) &&
           assert(result.status)(equalTo(RideStatus.Assigned))
    }.provide(serviceLayer),

    test("assignDriverToRide should fail when ride not found") {
      val rideId = RideId(999L)
      val requesterId = PersonId(4)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.assignDriverToRide(rideId, requesterId).flip
      yield assert(result)(isSubtype[RideError.RideNotFound](anything))
    }.provide(serviceLayer),

    test("assignDriverToRide should fail when ride already assigned") {
      val rideId = RideId(2L)
      val requesterId = PersonId(4)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.assignDriverToRide(rideId, requesterId).flip
      yield assert(result)(isSubtype[RideError.RideAlreadyAssigned](anything))
    }.provide(serviceLayer),

    test("assignDriverToRide should fail when no drivers available") {
      val rideId = RideId(4L)
      val requesterId = PersonId(4)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.assignDriverToRide(rideId, requesterId).flip
      yield assert(result)(isSubtype[RideError.NoDriversAvailable](anything))
    }.provide(serviceLayer),

    test("startRide should successfully start assigned ride") {
      val rideId = RideId(2L)
      val driverId = PersonId(10)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.startRide(rideId, driverId)
      yield assert(result.status)(equalTo(RideStatus.InProgress))
    }.provide(serviceLayer),

    test("startRide should fail when driver not authorized") {
      val rideId = RideId(2L)
      val wrongDriverId = PersonId(11)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.startRide(rideId, wrongDriverId).flip
      yield assert(result)(isSubtype[RideError.UnauthorizedAccess](anything))
    }.provide(serviceLayer),

    test("startRide should fail with invalid status transition") {
      val rideId = RideId(1L) 
      val driverId = PersonId(10)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.startRide(rideId, driverId).flip
      yield assert(result)(isSubtype[RideError.UnauthorizedAccess](anything))
    }.provide(serviceLayer),

    test("completeRide should successfully complete in-progress ride") {
      val rideId = RideId(3L)
      val driverId = PersonId(10)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.completeRide(rideId, driverId)
      yield assert(result.status)(equalTo(RideStatus.Completed))
    }.provide(serviceLayer),

    test("completeRide should fail when driver not authorized") {
      val rideId = RideId(3L)
      val wrongDriverId = PersonId(11)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.completeRide(rideId, wrongDriverId).flip
      yield assert(result)(isSubtype[RideError.UnauthorizedAccess](anything))
    }.provide(serviceLayer),

    test("cancelRide should successfully cancel ride for authorized user") {
      val rideId = RideId(1L)
      val userId = PersonId(1)
      val userRole = PersonRole.client

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.cancelRide(rideId, userId, userRole)
      yield assert(result.status)(equalTo(RideStatus.Cancelled))
    }.provide(serviceLayer),

    test("cancelRide should fail when user not authorized") {
      val rideId = RideId(1L)
      val unauthorizedUserId = PersonId(5)
      val userRole = PersonRole.client

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.cancelRide(rideId, unauthorizedUserId, userRole).flip
      yield assert(result)(isSubtype[RideError.UnauthorizedAccess](anything))
    }.provide(serviceLayer),

    test("getRideById should return ride when exists") {
      val rideId = RideId(1L)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.getRideById(rideId)
      yield assert(result.id)(equalTo(rideId))
    }.provide(serviceLayer),

    test("getRideById should fail when ride not found") {
      val rideId = RideId(999L)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.getRideById(rideId).flip
      yield assert(result)(isSubtype[RideError.RideNotFound](anything))
    }.provide(serviceLayer),

    test("getRidesForUser should return client rides for client user") {
      val clientId = PersonId(1)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.getRidesForUser(clientId)
      yield assert(result.nonEmpty)(isTrue) &&
           assert(result.forall(_.clientId == clientId))(isTrue)
    }.provide(serviceLayer),

    test("getRidesForUser should return driver rides for driver user") {
      val driverId = PersonId(10)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.getRidesForUser(driverId)
      yield assert(result.nonEmpty)(isTrue) &&
           assert(result.forall(_.driverId.contains(driverId)))(isTrue)
    }.provide(serviceLayer),

    test("getRidesForUser should return company rides for secretary") {
      val secretaryId = PersonId(3)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.getRidesForUser(secretaryId)
      yield assert(result.nonEmpty)(isTrue)
    }.provide(serviceLayer),

    test("getRidesForUser should fail when user not found") {
      val userId = PersonId(999)

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.getRidesForUser(userId).flip
      yield assert(result)(isSubtype[RideError.PersonNotFound](anything))
    }.provide(serviceLayer),

    test("enrichRideWithFlightInfo should update ride with flight info") {
      val ride = TestDataFactory.createRideWithFlight()

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.enrichRideWithFlightInfo(ride)
      yield assert(result.flightInfo.isDefined)(isTrue) &&
           assert(result.flightInfo.get.flightNumber)(equalTo("KL123"))
    }.provide(serviceLayer),

    test("enrichRideWithFlightInfo should return ride unchanged when no flight info") {
      val ride = TestDataFactory.createRideWithoutFlight()

      for
        service <- ZIO.service[RideApplicationService]
        result <- service.enrichRideWithFlightInfo(ride)
      yield assert(result)(equalTo(ride))
    }.provide(serviceLayer)
  )


case class MockRideRepository() extends RideRepository:
  private val rides = collection.mutable.Map[RideId, Ride](
    RideId(1L) -> TestDataFactory.createRide(RideId(1L), PersonId(1)),
    RideId(2L) -> TestDataFactory.createAssignedRide(RideId(2L), PersonId(1), PersonId(10)),
    RideId(3L) -> TestDataFactory.createInProgressRide(RideId(3L), PersonId(1), PersonId(10)),
    RideId(4L) -> TestDataFactory.createRideNoDrivers(RideId(4L), PersonId(1))
  )

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

case class MockDriverRepository() extends DriverRepository:
  private val drivers = List(
    TestDataFactory.createDriver(PersonId(10), CompanyId(1)),
    TestDataFactory.createDriver(PersonId(11), CompanyId(1))
  )

  def findAvailableNear(location: Location, radius: Distance): IO[RepositoryError, List[Driver]] = 
    location.address match
      case "Remote Location" => ZIO.succeed(List.empty)  
      case _ => ZIO.succeed(drivers)

  def findById(id: PersonId): IO[RepositoryError, Option[Driver]] = 
    ZIO.succeed(drivers.find(_.id == id))
    
  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Driver]] = 
    ZIO.succeed(drivers.filter(_.companyId == companyId))
    
  def updateStatus(driverId: PersonId, status: DriverStatus): IO[RepositoryError, Unit] = 
    ZIO.unit
    
  def updateLocation(driverId: PersonId, location: Location): IO[RepositoryError, Unit] = 
    ZIO.unit
    
  def save(driver: Driver): IO[RepositoryError, Driver] = 
    ZIO.succeed(driver)

case class MockPersonRepository() extends PersonRepository:
  private val people = Map(
    PersonId(1) -> TestDataFactory.createClient(PersonId(1), CompanyId(1)),
    PersonId(10) -> TestDataFactory.createDriverPerson(PersonId(10), CompanyId(1)),
    PersonId(11) -> TestDataFactory.createDriverPerson(PersonId(11), CompanyId(1)),
    PersonId(3) -> TestDataFactory.createSecretary(PersonId(3), CompanyId(1)),
    PersonId(4) -> TestDataFactory.createDispatcher(PersonId(4), CompanyId(1)),
    PersonId(2) -> TestDataFactory.createDispatcher(PersonId(2), CompanyId(1))
  )

  def findById(id: PersonId): IO[RepositoryError, Option[Person]] = 
    ZIO.succeed(people.get(id))

  def findByEmail(email: String): IO[RepositoryError, Option[Person]] = 
    ZIO.succeed(people.values.find(_.email == email))
    
  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Person]] = 
    ZIO.succeed(people.values.filter(_.companyId.contains(companyId)).toList)
    
  def save(person: Person): IO[RepositoryError, Person] = ZIO.succeed(person)

case class MockTariffRepository() extends TariffRepository:
  private val tariffs = Map(
    CompanyId(1) -> TestDataFactory.createTariff(CompanyId(1))
  )

  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, Option[Tariff]] = 
    ZIO.succeed(tariffs.get(companyId))

  def save(tariff: Tariff, companyId: CompanyId): IO[RepositoryError, Unit] = ZIO.unit

case class MockOldNotificationService() extends NotificationService:
  def notifyDriver(driverId: PersonId, message: String, rideId: Option[RideId]): IO[NotificationError, Unit] = ZIO.unit
  def notifyClient(clientId: PersonId, message: String, rideId: Option[RideId]): IO[NotificationError, Unit] = ZIO.unit
  def notifyCompany(companyId: CompanyId, message: String, rideId: Option[RideId]): IO[NotificationError, Unit] = ZIO.unit
  def sendSMSNotification(phoneNumber: String, message: String): IO[NotificationError, Unit] = ZIO.unit
  def sendEmailNotification(email: String, subject: String, message: String): IO[NotificationError, Unit] = ZIO.unit

case class MockLocationService() extends LocationService:
  def calculateRoute(from: Location, to: Location): IO[LocationError, RouteInfo] = 
    ZIO.succeed(RouteInfo(Distance(10.0), java.time.Duration.ofMinutes(20)))
    
  def getEstimatedDistance(from: Location, to: Location): IO[LocationError, Distance] = 
    ZIO.succeed(Distance(10.0))
    
  def geocodeAddress(address: String): IO[LocationError, Location] = 
    ZIO.succeed(Location(address, Some(50.0), Some(30.0)))
    
  def reverseGeocode(latitude: Double, longitude: Double): IO[LocationError, String] = 
    ZIO.succeed("Test Address")

case class MockFlightInfoService() extends FlightInfoService:
  def getFlightInfo(flightNumber: String, date: java.time.LocalDate): IO[FlightError, Option[FlightInfo]] = 
    ZIO.succeed(Some(FlightInfo(flightNumber, LocalDateTime.now(), isArrival = true)))
    
  def getAirportArrivals(airportCode: String, from: java.time.LocalDateTime, to: java.time.LocalDateTime): IO[FlightError, List[FlightInfo]] = 
    ZIO.succeed(List.empty)
    
  def getAirportDepartures(airportCode: String, from: java.time.LocalDateTime, to: java.time.LocalDateTime): IO[FlightError, List[FlightInfo]] = 
    ZIO.succeed(List.empty)


object TestDataFactory:
  def createRide(id: RideId, clientId: PersonId): Ride = 
    Ride(
      id = id,
      clientId = clientId,
      creatorId = PersonId(2),
      companyId = CompanyId(1),
      pickupDateTime = LocalDateTime.now().plusHours(2),
      from = Location("Airport", Some(50.0), Some(30.0)),
      to = Location("Hotel", Some(50.1), Some(30.1)),
      status = RideStatus.Requested,
      price = Some(Price(25.0, "USD")),
      estimatedDistance = Some(Distance(10.0))
    )

  def createAssignedRide(id: RideId, clientId: PersonId, driverId: PersonId): Ride = 
    createRide(id, clientId).copy(
      status = RideStatus.Assigned,
      driverId = Some(driverId)
    )

  def createInProgressRide(id: RideId, clientId: PersonId, driverId: PersonId): Ride = 
    createRide(id, clientId).copy(
      status = RideStatus.InProgress,
      driverId = Some(driverId)
    )
    
  def createRideNoDrivers(id: RideId, clientId: PersonId): Ride = 
    Ride(
      id = id,
      clientId = clientId,
      creatorId = PersonId(2),
      companyId = CompanyId(1),
      pickupDateTime = LocalDateTime.now().plusHours(2),
      from = Location("Remote Location", Some(55.0), Some(35.0)),  
      to = Location("Hotel", Some(50.1), Some(30.1)),
      status = RideStatus.Requested,
      price = Some(Price(25.0, "USD")),
      estimatedDistance = Some(Distance(10.0))
    )

  def createRideWithFlight(): Ride = 
    createRide(RideId(100L), PersonId(1)).copy(
      flightInfo = Some(FlightInfo("KL123", LocalDateTime.now(), isArrival = true))
    )

  def createRideWithoutFlight(): Ride = 
    createRide(RideId(101L), PersonId(1))

  def createClient(id: PersonId, companyId: CompanyId): Person = 
    Person(
      id = id,
      name = "Test Client",
      email = "client@test.com",
      role = PersonRole.client,
      companyId = Some(companyId)
    )

  def createDriver(id: PersonId, companyId: CompanyId): Driver = 
    Driver(
      id = id,
      name = "Test Driver",
      currentLocation = Location("Driver Location", Some(50.0), Some(30.0)),
      status = DriverStatus.Available,
      companyId = companyId
    )
    
  def createDriverPerson(id: PersonId, companyId: CompanyId): Person = 
    Person(
      id = id,
      name = "Test Driver",
      email = "driver@test.com",
      role = PersonRole.driver,
      companyId = Some(companyId)
    )

  def createSecretary(id: PersonId, companyId: CompanyId): Person = 
    Person(
      id = id,
      name = "Test Secretary",
      email = "secretary@test.com",
      role = PersonRole.secretary,
      companyId = Some(companyId)
    )

  def createDispatcher(id: PersonId, companyId: CompanyId): Person = 
    Person(
      id = id,
      name = "Test Dispatcher",
      email = "dispatcher@test.com",
      role = PersonRole.dispatcher,
      companyId = Some(companyId)
    )

  def createTariff(companyId: CompanyId): Tariff = 
    Tariff(
      basePrice = Price(5.0, "USD"),
      pricePerKm = Price(1.5, "USD"),
      airportSurcharge = Price(5.0, "USD"),
      nightSurcharge = Price(2.0, "USD")
    )