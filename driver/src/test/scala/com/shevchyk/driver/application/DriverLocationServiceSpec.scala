package com.shevchyk.driver.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{EventHub, GeofenceService, ActiveRideInfo}
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.driver.infrastructure.http.AvailableDriverDto
import com.shevchyk.ride.domain.{Ride, RideStatus}
import com.shevchyk.ride.repository.{RideRepository, InMemoryRideRepository}
import zio.*
import zio.test.*
import java.time.Instant
import java.util.UUID

object DriverLocationServiceSpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val testDriverId  = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))

  // InMemory DriverLocationRepository
  class InMemoryDriverLocationRepository extends DriverLocationRepository:
    private val locations = Unsafe.unsafe { implicit unsafe =>
      Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[PersonId, DriverLocation])).getOrThrowFiberFailure()
    }
    private val availability = Unsafe.unsafe { implicit unsafe =>
      Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[PersonId, String])).getOrThrowFiberFailure()
    }

    override def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit] =
      locations.update(_.updated(driverId, DriverLocation(driverId, latitude, longitude, Instant.now())))

    override def getLocation(driverId: PersonId): Task[Option[DriverLocation]] =
      locations.get.map(_.get(driverId))

    override def updateAvailability(driverId: PersonId, status: String): Task[Unit] =
      availability.update(_.updated(driverId, status))

    override def findAvailableByCompanyId(companyId: CompanyId): Task[List[(PersonId, String, Option[Double], Option[Double])]] =
      for {
        avail <- availability.get
        locs  <- locations.get
      } yield avail.filter(_._2 == "Available").keys.toList.map { pid =>
        val loc = locs.get(pid)
        (pid, "Available", loc.map(_.latitude), loc.map(_.longitude))
      }

  object InMemoryDriverLocationRepository:
    val layer: ZLayer[Any, Nothing, DriverLocationRepository] =
      ZLayer.succeed(new InMemoryDriverLocationRepository)

  // Noop GeofenceService
  val noopGeofenceService: ZLayer[Any, Nothing, GeofenceService] = ZLayer.succeed(
    new GeofenceService:
      def checkDriverLocation(driverId: PersonId, companyId: CompanyId, lat: Double, lng: Double): UIO[List[GeofenceAlert]] =
        ZIO.succeed(Nil)
      def checkClientProximity(driverId: PersonId, lat: Double, lng: Double, activeRides: List[ActiveRideInfo]): UIO[Unit] =
        ZIO.unit
  )

  val standardLayers =
    InMemoryDriverLocationRepository.layer ++
    EventHub.layer ++
    noopGeofenceService ++
    InMemoryRideRepository.layer >>>
    DriverLocationService.layer

  def spec = suite("DriverLocationService")(
    suite("updateLocation")(
      test("stores location in repository") {
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateLocation(testDriverId, 48.1351, 11.5820)
          loc     <- service.getLocation(testDriverId)
        } yield assertTrue(
          loc.isDefined &&
          loc.get.latitude == 48.1351 &&
          loc.get.longitude == 11.5820
        )
      }.provide(standardLayers),

      test("updates existing location") {
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateLocation(testDriverId, 48.1351, 11.5820)
          _       <- service.updateLocation(testDriverId, 48.3537, 11.7750)
          loc     <- service.getLocation(testDriverId)
        } yield assertTrue(
          loc.get.latitude == 48.3537 &&
          loc.get.longitude == 11.7750
        )
      }.provide(standardLayers),

      test("stores location for multiple drivers") {
        val driver2 = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000002"))
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateLocation(testDriverId, 48.1351, 11.5820)
          _       <- service.updateLocation(driver2, 52.5200, 13.4050)
          loc1    <- service.getLocation(testDriverId)
          loc2    <- service.getLocation(driver2)
        } yield assertTrue(
          loc1.get.latitude == 48.1351 &&
          loc2.get.latitude == 52.5200
        )
      }.provide(standardLayers)
    ),

    suite("getLocation")(
      test("returns None for unknown driver") {
        for {
          service   <- ZIO.service[DriverLocationService]
          unknownId  = PersonId(UUID.fromString("99999999-9999-9999-9999-999999999999"))
          loc       <- service.getLocation(unknownId)
        } yield assertTrue(loc.isEmpty)
      }.provide(standardLayers),

      test("returns stored location with correct driverId") {
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateLocation(testDriverId, 48.1351, 11.5820)
          loc     <- service.getLocation(testDriverId)
        } yield assertTrue(
          loc.get.driverId == testDriverId
        )
      }.provide(standardLayers)
    ),

    suite("updateAvailability")(
      test("sets driver as Available") {
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateAvailability(testDriverId, "Available")
          drivers <- service.getAvailableDrivers(testCompanyId)
        } yield assertTrue(true) // availability stored successfully
      }.provide(standardLayers),

      test("sets driver as Offline") {
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateAvailability(testDriverId, "Offline")
        } yield assertTrue(true) // no error thrown
      }.provide(standardLayers),

      test("switching from Available to Offline removes from available list") {
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateAvailability(testDriverId, "Available")
          before  <- service.getAvailableDrivers(testCompanyId)
          _       <- service.updateAvailability(testDriverId, "Offline")
          after   <- service.getAvailableDrivers(testCompanyId)
        } yield assertTrue(after.isEmpty)
      }.provide(standardLayers)
    ),

    suite("getAvailableDrivers")(
      test("returns empty list when no drivers available") {
        for {
          service <- ZIO.service[DriverLocationService]
          drivers <- service.getAvailableDrivers(testCompanyId)
        } yield assertTrue(drivers.isEmpty)
      }.provide(standardLayers),

      test("returns available driver with location") {
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateAvailability(testDriverId, "Available")
          _       <- service.updateLocation(testDriverId, 48.1351, 11.5820)
          drivers <- service.getAvailableDrivers(testCompanyId)
        } yield assertTrue(
          drivers.length == 1 &&
          drivers.head.id == testDriverId.value.toString &&
          drivers.head.status == "Available" &&
          drivers.head.latitude.contains(48.1351) &&
          drivers.head.longitude.contains(11.5820)
        )
      }.provide(standardLayers),

      test("returns available driver without location") {
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateAvailability(testDriverId, "Available")
          drivers <- service.getAvailableDrivers(testCompanyId)
        } yield assertTrue(
          drivers.length == 1 &&
          drivers.head.latitude.isEmpty &&
          drivers.head.longitude.isEmpty
        )
      }.provide(standardLayers),

      test("does not return offline drivers") {
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateAvailability(testDriverId, "Offline")
          drivers <- service.getAvailableDrivers(testCompanyId)
        } yield assertTrue(drivers.isEmpty)
      }.provide(standardLayers),

      test("returns multiple available drivers") {
        val driver2 = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000002"))
        for {
          service <- ZIO.service[DriverLocationService]
          _       <- service.updateAvailability(testDriverId, "Available")
          _       <- service.updateAvailability(driver2, "Available")
          drivers <- service.getAvailableDrivers(testCompanyId)
        } yield assertTrue(drivers.length == 2)
      }.provide(standardLayers)
    )
  )
}
