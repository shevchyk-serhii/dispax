package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*
import zio.test.*
import zio.test.Assertion.*

object DriverAssignmentServiceSpec extends ZIOSpecDefault:

  
  val mockRideRepo = ZLayer.succeed(MockDriverAssignmentRideRepo())
  val mockDriverRepo = ZLayer.succeed(MockDriverAssignmentDriverRepo())

  val serviceLayer = mockRideRepo ++ mockDriverRepo >>> DriverAssignmentService.layer

  def spec = suite("DriverAssignmentService")(

    test("should successfully assign available driver to unassigned ride") {
      val rideId = RideId(1L)
      val requesterId = PersonId(4)

      for
        service <- ZIO.service[DriverAssignmentService]
        result <- service.assignDriverToRide(rideId, requesterId)
      yield assert(result.ride.driverId.isDefined)(isTrue) &&
           assert(result.ride.status)(equalTo(RideStatus.Assigned)) &&
           assert(result.assignedDriver.status)(equalTo(DriverStatus.Available)) && 
           assert(result.searchRadius.kilometers)(isLessThanEqualTo(20.0))
    }.provide(serviceLayer),

    test("should fail when ride is not found") {
      val rideId = RideId(999L)
      val requesterId = PersonId(4)

      for
        service <- ZIO.service[DriverAssignmentService]
        result <- service.assignDriverToRide(rideId, requesterId).flip
      yield assert(result)(isSubtype[RideError.RideNotFound](anything))
    }.provide(serviceLayer),

    test("should fail when ride is already assigned") {
      val rideId = RideId(2L) 
      val requesterId = PersonId(4)

      for
        service <- ZIO.service[DriverAssignmentService]  
        result <- service.assignDriverToRide(rideId, requesterId).flip
      yield assert(result)(isSubtype[RideError.RideAlreadyAssigned](anything))
    }.provide(serviceLayer),

    test("should fail when no drivers available in area") {
      val rideId = RideId(4L) 
      val requesterId = PersonId(4)

      for
        service <- ZIO.service[DriverAssignmentService]
        result <- service.assignDriverToRide(rideId, requesterId).flip
      yield assert(result)(isSubtype[RideError.NoDriversAvailable](anything))
    }.provide(serviceLayer),

    test("should expand search radius when no drivers found nearby") {
      val rideId = RideId(5L) 
      val requesterId = PersonId(4)

      for
        service <- ZIO.service[DriverAssignmentService]
        result <- service.assignDriverToRide(rideId, requesterId)
      yield assert(result.ride.driverId.isDefined)(isTrue) &&
           assert(result.searchRadius.kilometers)(isGreaterThan(5.0)) 
    }.provide(serviceLayer),


    test("should find available drivers within radius") {
      val location = Location("City Center", Some(50.0), Some(30.0))
      val radius = Distance(10.0)

      for
        service <- ZIO.service[DriverAssignmentService]
        result <- service.findAvailableDrivers(location, radius)
      yield assert(result.nonEmpty)(isTrue) &&
           assert(result.forall(_.status == DriverStatus.Available))(isTrue)
    }.provide(serviceLayer),

    test("should return empty list when no drivers in radius") {
      val location = Location("Remote Location", Some(55.0), Some(35.0))
      val radius = Distance(5.0)

      for
        service <- ZIO.service[DriverAssignmentService]
        result <- service.findAvailableDrivers(location, radius)
      yield assert(result)(isEmpty)
    }.provide(serviceLayer),

    test("should handle concurrent assignment requests gracefully") {
      val rideId = RideId(6L)
      val requesterId = PersonId(4)

      for
        service <- ZIO.service[DriverAssignmentService]
        
        results <- ZIO.collectAllPar(List.fill(3)(
          service.assignDriverToRide(rideId, requesterId).either
        ))
        successCount = results.count(_.isRight)
      yield assert(successCount)(isGreaterThanEqualTo(1)) 
    }.provide(serviceLayer)
  )


case class MockDriverAssignmentRideRepo() extends RideRepository:
  private val rides = collection.mutable.Map[RideId, Ride](
    RideId(1L) -> createRide(RideId(1L), "City Center"),
    RideId(2L) -> createAssignedRide(RideId(2L), "Downtown", PersonId(10)),
    RideId(4L) -> createRide(RideId(4L), "Remote Location"), 
    RideId(5L) -> createRide(RideId(5L), "Suburban Area"),   
    RideId(6L) -> createRide(RideId(6L), "Business District") 
  )

  private def createRide(id: RideId, fromAddress: String): Ride =
    Ride(
      id = id,
      clientId = PersonId(1),
      creatorId = PersonId(2),
      companyId = CompanyId(1),
      pickupDateTime = java.time.LocalDateTime.now().plusHours(2),
      from = Location(fromAddress, Some(50.0), Some(30.0)),
      to = Location("Hotel", Some(50.1), Some(30.1)),
      status = RideStatus.Requested
    )

  private def createAssignedRide(id: RideId, fromAddress: String, driverId: PersonId): Ride =
    createRide(id, fromAddress).copy(
      status = RideStatus.Assigned,
      driverId = Some(driverId)
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

case class MockDriverAssignmentDriverRepo() extends DriverRepository:
  private val drivers = List(
    Driver(PersonId(10), "Driver A", Location("City Area", Some(50.0), Some(30.0)), DriverStatus.Available, CompanyId(1)),
    Driver(PersonId(11), "Driver B", Location("Downtown", Some(50.05), Some(30.05)), DriverStatus.Available, CompanyId(1)),
    Driver(PersonId(12), "Driver C", Location("Suburban Area", Some(50.2), Some(30.2)), DriverStatus.Available, CompanyId(1))
  )

  private var driverStatuses = collection.mutable.Map[PersonId, DriverStatus](
    PersonId(10) -> DriverStatus.Available,
    PersonId(11) -> DriverStatus.Available, 
    PersonId(12) -> DriverStatus.Available
  )

  def findAvailableNear(location: Location, radius: Distance): IO[RepositoryError, List[Driver]] = 
    location.address match
      case "Remote Location" => ZIO.succeed(List.empty) 
      case "Suburban Area" => 
        
        if radius.kilometers <= 5.0 then ZIO.succeed(List.empty)
        else ZIO.succeed(drivers.filter(d => driverStatuses(d.id) == DriverStatus.Available))
      case _ => 
        ZIO.succeed(drivers.filter(d => driverStatuses(d.id) == DriverStatus.Available))

  def findById(id: PersonId): IO[RepositoryError, Option[Driver]] = 
    ZIO.succeed(drivers.find(_.id == id))
    
  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Driver]] = 
    ZIO.succeed(drivers.filter(_.companyId == companyId))
    
  def updateStatus(driverId: PersonId, status: DriverStatus): IO[RepositoryError, Unit] = 
    ZIO.succeed(driverStatuses(driverId) = status)
    
  def updateLocation(driverId: PersonId, location: Location): IO[RepositoryError, Unit] = 
    ZIO.unit
    
  def save(driver: Driver): IO[RepositoryError, Driver] = 
    ZIO.succeed(driver)