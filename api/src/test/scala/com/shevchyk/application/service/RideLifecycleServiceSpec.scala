package com.shevchyk.application.service

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import com.shevchyk.application.errors.*
import zio.*
import zio.test.*
import zio.test.Assertion.*

object RideLifecycleServiceSpec extends ZIOSpecDefault:

  val mockRideRepo = ZLayer.succeed(MockLifecycleRideRepo())
  val mockDriverRepo = ZLayer.succeed(MockLifecycleDriverRepo())

  val serviceLayer = mockRideRepo ++ mockDriverRepo >>> RideLifecycleService.layer

  def spec = suite("RideLifecycleService")(

    test("should successfully start assigned ride") {
      val rideId = RideId(2L) 
      val driverId = PersonId(10)

      for
        service <- ZIO.service[RideLifecycleService]
        result <- service.startRide(rideId, driverId)
      yield assert(result.newStatus)(equalTo(RideStatus.InProgress)) &&
           assert(result.ride.status)(equalTo(RideStatus.InProgress)) &&
           assert(result.triggeredBy)(equalTo(driverId))
    }.provide(serviceLayer),

    test("should fail to start ride when driver not authorized") {
      val rideId = RideId(2L) 
      val wrongDriverId = PersonId(11) 

      for
        service <- ZIO.service[RideLifecycleService]
        result <- service.startRide(rideId, wrongDriverId).flip
      yield assert(result)(isSubtype[RideError.UnauthorizedAccess](anything))
    }.provide(serviceLayer),

    test("should successfully complete in-progress ride") {
      val rideId = RideId(3L) 
      val driverId = PersonId(10)

      for
        service <- ZIO.service[RideLifecycleService]
        result <- service.completeRide(rideId, driverId)
      yield assert(result.ride.status)(equalTo(RideStatus.Completed)) &&
           assert(result.completedBy)(equalTo(driverId))
    }.provide(serviceLayer),

    test("should free driver when completing ride") {
      val rideId = RideId(3L)
      val driverId = PersonId(10)

      for
        service <- ZIO.service[RideLifecycleService]
        _ <- service.completeRide(rideId, driverId)
        
      yield assert(true)(isTrue) 
    }.provide(serviceLayer),

    test("should successfully cancel ride when authorized") {
      val rideId = RideId(1L)
      val userId = PersonId(1) 
      val userRole = PersonRole.client

      for
        service <- ZIO.service[RideLifecycleService]
        result <- service.cancelRide(rideId, userId, userRole)
      yield assert(result.ride.status)(equalTo(RideStatus.Cancelled)) &&
           assert(result.cancelledBy)(equalTo(userId))
    }.provide(serviceLayer),

    test("should fail to cancel when user not authorized") {
      val rideId = RideId(1L)
      val unauthorizedUserId = PersonId(5)
      val userRole = PersonRole.client

      for
        service <- ZIO.service[RideLifecycleService]
        result <- service.cancelRide(rideId, unauthorizedUserId, userRole).flip
      yield assert(result)(isSubtype[RideError.UnauthorizedAccess](anything))
    }.provide(serviceLayer),


    test("should handle invalid state transitions gracefully") {
      val rideId = RideId(1L) 
      val driverId = PersonId(10)

      for
        service <- ZIO.service[RideLifecycleService]
        result <- service.startRide(rideId, driverId).flip
      yield assert(result)(isSubtype[RideError.UnauthorizedAccess](anything))
    }.provide(serviceLayer)
  )


case class MockLifecycleRideRepo() extends RideRepository:
  private val rides = collection.mutable.Map[RideId, Ride](
    RideId(1L) -> Ride(
      id = RideId(1L),
      clientId = PersonId(1),
      creatorId = PersonId(2),
      driverId = None,
      companyId = CompanyId(1),
      pickupDateTime = java.time.LocalDateTime.now().plusHours(2),
      from = Location("Start", None, None),
      to = Location("End", None, None),
      status = RideStatus.Requested
    ),
    RideId(2L) -> Ride(
      id = RideId(2L),
      clientId = PersonId(1),
      creatorId = PersonId(2),
      driverId = Some(PersonId(10)),
      companyId = CompanyId(1),
      pickupDateTime = java.time.LocalDateTime.now().plusHours(2),
      from = Location("Start", None, None),
      to = Location("End", None, None),
      status = RideStatus.Assigned
    ),
    RideId(3L) -> Ride(
      id = RideId(3L),
      clientId = PersonId(1),
      creatorId = PersonId(2),
      driverId = Some(PersonId(10)),
      companyId = CompanyId(1),
      pickupDateTime = java.time.LocalDateTime.now().plusHours(2),
      from = Location("Start", None, None),
      to = Location("End", None, None),
      status = RideStatus.InProgress
    )
  )

  def save(ride: Ride): IO[RepositoryError, Ride] = ZIO.succeed(ride)
  
  def update(ride: Ride): IO[RepositoryError, Option[Ride]] = 
    ZIO.succeed {
      rides.get(ride.id).map { _ =>
        rides(ride.id) = ride
        ride
      }
    }

  def findById(id: RideId): IO[RepositoryError, Option[Ride]] = 
    ZIO.succeed(rides.get(id))

  def findByClientId(clientId: PersonId): IO[RepositoryError, List[Ride]] = ZIO.succeed(List.empty)
  def findByDriverId(driverId: PersonId): IO[RepositoryError, List[Ride]] = ZIO.succeed(List.empty)
  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Ride]] = ZIO.succeed(List.empty)
  def findByStatus(status: RideStatus): IO[RepositoryError, List[Ride]] = ZIO.succeed(List.empty)
  def findAll(): IO[RepositoryError, List[Ride]] = ZIO.succeed(List.empty)
  def delete(id: RideId): IO[RepositoryError, Boolean] = ZIO.succeed(false)

case class MockLifecycleDriverRepo() extends DriverRepository:
  def findAvailableNear(location: Location, radius: Distance): IO[RepositoryError, List[Driver]] = ZIO.succeed(List.empty)
  def findById(id: PersonId): IO[RepositoryError, Option[Driver]] = ZIO.succeed(None)
  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Driver]] = ZIO.succeed(List.empty)
  def updateStatus(driverId: PersonId, status: DriverStatus): IO[RepositoryError, Unit] = ZIO.unit
  def updateLocation(driverId: PersonId, location: Location): IO[RepositoryError, Unit] = ZIO.unit
  def save(driver: Driver): IO[RepositoryError, Driver] = ZIO.succeed(driver)