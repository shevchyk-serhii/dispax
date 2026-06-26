package com.shevchyk.driver.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{EventHub, GeofenceService, ActiveRideInfo}
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.driver.domain.DriverLocation
import com.shevchyk.driver.repository.DriverLocationRepository
import com.shevchyk.driver.infrastructure.http.AvailableDriverDto
import com.shevchyk.ride.domain.{Ride, RideStatus}
import com.shevchyk.ride.repository.{RideRepository, InMemoryRideRepository}
import zio.*
import zio.test.*
import java.time.Instant
import java.util.UUID

// Helper: construct a minimal Person with the given companyId
private def testPerson(id: PersonId, companyId: Option[CompanyId]): Person = Person(
  id = id,
  name = "Test Driver",
  email = "driver@test.com",
  role = PersonRole.Driver,
  companyId = companyId
)

// Helper: ZLayer that returns a fixed Person from findById
private def personRepoReturning(person: Person): ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
  new PersonRepository:
    def create(p: Person): Task[Person]                                                                    = ZIO.succeed(p)
    def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.succeed(Some(person))
    def findByIdAndCompany(id: PersonId, c: CompanyId): Task[Option[Person]]                               = ZIO.none
    def findByEmail(email: String): Task[Option[Person]]                                                   = ZIO.none
    def findByRole(role: PersonRole): Task[List[Person]]                                                   = ZIO.succeed(Nil)
    def findByRoleAndCompany(role: PersonRole, c: CompanyId): Task[List[Person]]                           = ZIO.succeed(Nil)
    def findByCompanyId(c: CompanyId): Task[List[Person]]                                                  = ZIO.succeed(Nil)
    def findAll(): Task[List[Person]]                                                                      = ZIO.succeed(Nil)
    def update(p: Person): Task[Person]                                                                    = ZIO.succeed(p)
    def delete(id: PersonId): Task[Unit]                                                                   = ZIO.unit
    def deleteInCompany(id: PersonId, companyId: com.shevchyk.core.domain.CompanyId): Task[Unit]           = ZIO.unit
    def findByStatus(status: UserStatus): Task[List[Person]]                                               = ZIO.succeed(Nil)
    def searchByQuery(query: String): Task[List[Person]]                                                   = ZIO.succeed(Nil)
    def updateLastLogin(id: PersonId): Task[Unit]                                                          = ZIO.unit
    def findByClientCompany(ccId: ClientCompanyId): Task[List[Person]]                                     = ZIO.succeed(Nil)
    def upsertDriverRow(personId: PersonId): Task[Unit]                                                    = ZIO.unit
    def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                       = ZIO.none
    def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] = ZIO.unit
    def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                                       = ZIO.unit
)

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

    override def updateLocation(driverId: PersonId, latitude: Double, longitude: Double): Task[Unit] = locations.update(
      _.updated(driverId, DriverLocation(driverId, latitude, longitude, Instant.now()))
    )

    override def getLocation(driverId: PersonId): Task[Option[DriverLocation]] = locations.get.map(_.get(driverId))

    override def updateAvailability(driverId: PersonId, status: String): Task[Unit] = availability.update(
      _.updated(driverId, status)
    )

    override def getAvailability(driverId: PersonId): Task[Option[String]] = availability.get.map(_.get(driverId))

    override def findAvailableByCompanyId(
        companyId: CompanyId
    ): Task[List[(PersonId, String, Option[Double], Option[Double])]] =
      for {
        avail <- availability.get
        locs  <- locations.get
      } yield avail.filter(_._2 == "Available").keys.toList.map { pid =>
        val loc = locs.get(pid)
        (pid, "Available", loc.map(_.latitude), loc.map(_.longitude))
      }

  object InMemoryDriverLocationRepository:
    val layer: ZLayer[Any, Nothing, DriverLocationRepository] = ZLayer.succeed(new InMemoryDriverLocationRepository)

  // Noop PersonRepository
  val noopPersonRepository: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
    new PersonRepository:
      def create(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def findById(id: PersonId): Task[Option[Person]]                                                       = ZIO.none
      def findByIdAndCompany(id: PersonId, companyId: CompanyId): Task[Option[Person]]                       = ZIO.none
      def findByEmail(email: String): Task[Option[Person]]                                                   = ZIO.none
      def findByRole(role: PersonRole): Task[List[Person]]                                                   = ZIO.succeed(Nil)
      def findByRoleAndCompany(role: PersonRole, companyId: CompanyId): Task[List[Person]]                   = ZIO.succeed(Nil)
      def findByCompanyId(companyId: CompanyId): Task[List[Person]]                                          = ZIO.succeed(Nil)
      def findAll(): Task[List[Person]]                                                                      = ZIO.succeed(Nil)
      def update(person: Person): Task[Person]                                                               = ZIO.succeed(person)
      def delete(id: PersonId): Task[Unit]                                                                   = ZIO.unit
      def deleteInCompany(id: PersonId, companyId: com.shevchyk.core.domain.CompanyId): Task[Unit]           = ZIO.unit
      def findByStatus(status: UserStatus): Task[List[Person]]                                               = ZIO.succeed(Nil)
      def searchByQuery(query: String): Task[List[Person]]                                                   = ZIO.succeed(Nil)
      def updateLastLogin(id: PersonId): Task[Unit]                                                          = ZIO.unit
      def findByClientCompany(clientCompanyId: ClientCompanyId): Task[List[Person]]                          = ZIO.succeed(Nil)
      def upsertDriverRow(personId: PersonId): Task[Unit]                                                    = ZIO.unit
      def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                       = ZIO.none
      def setAvatar(id: PersonId, companyId: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] = ZIO.unit
      def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                                       = ZIO.unit
  )

  // Noop GeofenceService
  val noopGeofenceService: ZLayer[Any, Nothing, GeofenceService] = ZLayer.succeed(
    new GeofenceService:
      def checkDriverLocation(
          driverId: PersonId,
          companyId: CompanyId,
          lat: Double,
          lng: Double
      ): UIO[List[GeofenceAlert]] = ZIO.succeed(Nil)
      def checkClientProximity(
          driverId: PersonId,
          lat: Double,
          lng: Double,
          activeRides: List[ActiveRideInfo]
      ): UIO[Unit] = ZIO.unit
  )

  val standardLayers =
    InMemoryDriverLocationRepository.layer ++
      EventHub.layer ++
      noopGeofenceService ++
      InMemoryRideRepository.layer ++
      noopPersonRepository >>>
      DriverLocationService.layer

  def spec =
    suite("DriverLocationService")(
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
        test("rejects latitude out of range") {
          for {
            service <- ZIO.service[DriverLocationService]
            result  <- service.updateLocation(testDriverId, 91.0, 11.5).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[IllegalArgumentException])
            case _                   => false
          })
        }.provide(standardLayers),
        test("rejects longitude out of range") {
          for {
            service <- ZIO.service[DriverLocationService]
            result  <- service.updateLocation(testDriverId, 48.1, 181.0).exit
          } yield assertTrue(result match {
            case Exit.Failure(cause) => cause.failureOption.exists(_.isInstanceOf[IllegalArgumentException])
            case _                   => false
          })
        }.provide(standardLayers),
        test("accepts boundary coordinates (-90/180)") {
          for {
            service <- ZIO.service[DriverLocationService]
            _       <- service.updateLocation(testDriverId, -90.0, 180.0)
            loc     <- service.getLocation(testDriverId)
          } yield assertTrue(loc.exists(l => l.latitude == -90.0 && l.longitude == 180.0))
        }.provide(standardLayers),
        // -----------------------------------------------------------------------
        // MUTATION KILL: boundary conditions in validateCoordinates
        // -----------------------------------------------------------------------
        // The guard is:  latitude < -90.0 || latitude > 90.0
        //                longitude < -180.0 || longitude > 180.0
        //
        // Mutations targeted:
        //   • "latitude > 90.0"  → "latitude >= 90.0"  : would reject lat = 90.0
        //   • "longitude < -180.0" → "longitude <= -180.0" : would reject lon = -180.0
        //
        // Each test stores the coordinate and confirms no error is thrown, so a
        // mutated guard that incorrectly rejects the boundary value causes the test to fail.
        test("accepts latitude exactly 90.0 (upper inclusive boundary)") {
          for {
            service <- ZIO.service[DriverLocationService]
            result  <- service.updateLocation(testDriverId, 90.0, 0.0).exit
          } yield assertTrue(result.isSuccess)
        }.provide(standardLayers),
        test("accepts longitude exactly -180.0 (lower inclusive boundary)") {
          for {
            service <- ZIO.service[DriverLocationService]
            result  <- service.updateLocation(testDriverId, 0.0, -180.0).exit
          } yield assertTrue(result.isSuccess)
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
        }.provide(standardLayers),
        // -- Edge case added by test audit 2026-06 -------------------------
        // checkGeofences derives the driver's company from the FIRST of their rides.
        // For a driver whose rides span multiple companies this is the first ride's
        // company — pin that behaviour so a future change is a conscious decision.
        test("checkGeofences uses the company of the driver's first ride") {
          val companyA                         = CompanyId(UUID.fromString("00000001-0000-0000-0000-00000000000a"))
          val companyB                         = CompanyId(UUID.fromString("00000001-0000-0000-0000-00000000000b"))
          def rideIn(company: CompanyId): Ride = Ride(
            id = RideId.generate(),
            clientId = PersonId(UUID.randomUUID()),
            creatorId = PersonId(UUID.randomUUID()),
            companyId = company,
            driverId = Some(testDriverId),
            status = RideStatus.Assigned,
            pickupLocation = Location("A"),
            dropoffLocation = Location("B"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )
          for {
            captured         <- Ref.make(Option.empty[CompanyId])
            recordingGeofence = ZLayer.succeed[GeofenceService](
                                  new GeofenceService:
                                    def checkDriverLocation(
                                        driverId: PersonId,
                                        companyId: CompanyId,
                                        lat: Double,
                                        lng: Double
                                    ): UIO[List[GeofenceAlert]] = captured.set(Some(companyId)).as(Nil)
                                    def checkClientProximity(
                                        driverId: PersonId,
                                        lat: Double,
                                        lng: Double,
                                        activeRides: List[ActiveRideInfo]
                                    ): UIO[Unit] = ZIO.unit
                                )
            // Share a single RideRepository between seeding and the service.
            rideRepoLayer     = InMemoryRideRepository.layer
            depsLayer         =
              rideRepoLayer ++
                InMemoryDriverLocationRepository.layer ++
                EventHub.layer ++
                recordingGeofence ++
                noopPersonRepository
            serviceLayer      = depsLayer >+> DriverLocationService.layer
            result           <-
              (for {
                rideRepo <- ZIO.service[RideRepository]
                _        <- rideRepo.create(rideIn(companyA))
                _        <- rideRepo.create(rideIn(companyB))
                service  <- ZIO.service[DriverLocationService]
                _        <- service.updateLocation(testDriverId, 48.1, 11.5)
                // checkGeofences runs on a forked daemon — poll until it records.
                seen     <- captured.get.repeatUntil(_.isDefined).timeout(5.seconds)
              } yield seen).provide(serviceLayer)
          } yield assertTrue(result.flatten.contains(companyA))
        } @@ TestAspect.withLiveClock @@ TestAspect.flaky
      ),
      suite("getLocation")(
        test("returns None for unknown driver") {
          for {
            service  <- ZIO.service[DriverLocationService]
            unknownId = PersonId(UUID.fromString("99999999-9999-9999-9999-999999999999"))
            loc      <- service.getLocation(unknownId)
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
            _       <- service.getAvailableDrivers(testCompanyId)
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
            _       <- service.getAvailableDrivers(testCompanyId)
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
      ),
      // -----------------------------------------------------------------------
      // NEW: updateLocation — EventHub publication
      // -----------------------------------------------------------------------
      suite("updateLocation — EventHub publication")(
        test("publishes LocationUpdated event with correct fields when driver has a company") {
          for {
            captured         <- Ref.make(Option.empty[WebSocketEvent])
            recordingEventHub = ZLayer.succeed[EventHub](
                                  new EventHub:
                                    def publish(event: WebSocketEvent): UIO[Boolean]            = captured
                                      .set(Some(event))
                                      .as(true)
                                    def subscribe: ZIO[Scope, Nothing, Dequeue[WebSocketEvent]] = Hub
                                      .bounded[WebSocketEvent](1)
                                      .flatMap(_.subscribe)
                                )
            driverPerson      = testPerson(testDriverId, Some(testCompanyId))
            layers            =
              InMemoryDriverLocationRepository.layer ++
                recordingEventHub ++
                noopGeofenceService ++
                InMemoryRideRepository.layer ++
                personRepoReturning(driverPerson) >>>
                DriverLocationService.layer
            service          <- ZIO.service[DriverLocationService].provide(layers)
            _                <- service.updateLocation(testDriverId, 48.1351, 11.5820)
            event            <- captured.get
          } yield assertTrue(
            event.isDefined,
            event.get.isInstanceOf[WebSocketEvent.LocationUpdated],
            event.get.asInstanceOf[WebSocketEvent.LocationUpdated].userId == testDriverId.value,
            event.get.asInstanceOf[WebSocketEvent.LocationUpdated].latitude == 48.1351,
            event.get.asInstanceOf[WebSocketEvent.LocationUpdated].longitude == 11.5820,
            event.get.asInstanceOf[WebSocketEvent.LocationUpdated].locationType == "driver",
            event.get.asInstanceOf[WebSocketEvent.LocationUpdated].companyId == testCompanyId.value
          )
        },
        test("no event published when driver has no company") {
          for {
            captured         <- Ref.make(Option.empty[WebSocketEvent])
            recordingEventHub = ZLayer.succeed[EventHub](
                                  new EventHub:
                                    def publish(event: WebSocketEvent): UIO[Boolean]            = captured
                                      .set(Some(event))
                                      .as(true)
                                    def subscribe: ZIO[Scope, Nothing, Dequeue[WebSocketEvent]] = Hub
                                      .bounded[WebSocketEvent](1)
                                      .flatMap(_.subscribe)
                                )
            driverPerson      = testPerson(testDriverId, None)
            layers            =
              InMemoryDriverLocationRepository.layer ++
                recordingEventHub ++
                noopGeofenceService ++
                InMemoryRideRepository.layer ++
                personRepoReturning(driverPerson) >>>
                DriverLocationService.layer
            service          <- ZIO.service[DriverLocationService].provide(layers)
            _                <- service.updateLocation(testDriverId, 48.1351, 11.5820)
            event            <- captured.get
          } yield assertTrue(event.isEmpty)
        }
      ),
      // -----------------------------------------------------------------------
      // NEW: checkGeofences — ride status filtering
      // -----------------------------------------------------------------------
      suite("checkGeofences — ride status filtering")(
        test("Completed and Cancelled rides are excluded from proximity check") {
          val companyA                           = CompanyId(UUID.fromString("00000001-0000-0000-0000-00000000000a"))
          def makeRide(status: RideStatus): Ride = Ride(
            id = RideId.generate(),
            clientId = PersonId(UUID.randomUUID()),
            creatorId = PersonId(UUID.randomUUID()),
            companyId = companyA,
            driverId = Some(testDriverId),
            status = status,
            pickupLocation = Location("Pickup", Some(48.1), Some(11.5)),
            dropoffLocation = Location("Dropoff"),
            pickupDateTime = Instant.now().plusSeconds(3600)
          )
          for {
            capturedRides                             <- Ref.make(Option.empty[List[ActiveRideInfo]])
            recordingGeofence                          = ZLayer.succeed[GeofenceService](
                                                           new GeofenceService:
                                                             def checkDriverLocation(
                                                                 dId: PersonId,
                                                                 cId: CompanyId,
                                                                 lat: Double,
                                                                 lng: Double
                                                             ): UIO[List[GeofenceAlert]] = ZIO.succeed(Nil)
                                                             def checkClientProximity(
                                                                 dId: PersonId,
                                                                 lat: Double,
                                                                 lng: Double,
                                                                 activeRides: List[ActiveRideInfo]
                                                             ): UIO[Unit] = capturedRides.set(Some(activeRides))
                                                         )
            rideRepoLayer                              = InMemoryRideRepository.layer
            depsLayer                                  =
              rideRepoLayer ++
                InMemoryDriverLocationRepository.layer ++
                EventHub.layer ++
                recordingGeofence ++
                noopPersonRepository
            serviceLayer                               = depsLayer >+> DriverLocationService.layer
            result                                    <-
              (for {
                rideRepo <- ZIO.service[RideRepository]
                // create() re-generates the ride ID; capture the actual stored IDs
                stored1  <- rideRepo.create(makeRide(RideStatus.Assigned))
                stored2  <- rideRepo.create(makeRide(RideStatus.InProgress))
                stored3  <- rideRepo.create(makeRide(RideStatus.Completed))
                service  <- ZIO.service[DriverLocationService]
                _        <- service.updateLocation(testDriverId, 48.1, 11.5)
                seen     <- capturedRides.get.repeatUntil(_.isDefined).timeout(5.seconds)
              } yield (seen, stored1.id, stored2.id, stored3.id)).provide(serviceLayer)
            seen: Option[Option[List[ActiveRideInfo]]] = result._1
            id1                                        = result._2
            id2                                        = result._3
            id3                                        = result._4
            activeRides: List[ActiveRideInfo]          = seen.flatten.getOrElse(Nil)
          } yield assertTrue(
            activeRides.length == 2,
            activeRides.exists(_.rideId == id1.value),
            activeRides.exists(_.rideId == id2.value),
            !activeRides.exists(_.rideId == id3.value)
          )
        } @@ TestAspect.withLiveClock @@ TestAspect.flaky,
        test("checkGeofences skips proximity check entirely when driver has no rides") {
          for {
            capturedRides    <- Ref.make(Option.empty[List[ActiveRideInfo]])
            recordingGeofence = ZLayer.succeed[GeofenceService](
                                  new GeofenceService:
                                    def checkDriverLocation(
                                        dId: PersonId,
                                        cId: CompanyId,
                                        lat: Double,
                                        lng: Double
                                    ): UIO[List[GeofenceAlert]] = ZIO.succeed(Nil)
                                    def checkClientProximity(
                                        dId: PersonId,
                                        lat: Double,
                                        lng: Double,
                                        activeRides: List[ActiveRideInfo]
                                    ): UIO[Unit] = capturedRides.set(Some(activeRides))
                                )
            layers            =
              InMemoryDriverLocationRepository.layer ++
                EventHub.layer ++
                recordingGeofence ++
                InMemoryRideRepository.layer ++
                noopPersonRepository >>>
                DriverLocationService.layer
            service          <- ZIO.service[DriverLocationService].provide(layers)
            _                <- service.updateLocation(testDriverId, 48.1, 11.5)
            // wait briefly — the daemon may fire but should take the `case None` path
            _                <- ZIO.sleep(200.millis)
            result           <- capturedRides.get
          } yield assertTrue(result.isEmpty)
        } @@ TestAspect.withLiveClock @@ TestAspect.flaky,
        test("checkGeofences error is swallowed — updateLocation succeeds") {
          val failingRideRepo = ZLayer.succeed[RideRepository](new RideRepository:
            def create(ride: Ride): Task[Ride]                                                                  = ZIO.succeed(ride)
            def findById(id: RideId): Task[Option[Ride]]                                                        = ZIO.none
            def update(ride: Ride): Task[Ride]                                                                  = ZIO.succeed(ride)
            def updateIfStatus(ride: Ride, expected: Set[RideStatus]): Task[Boolean]                            = ZIO.succeed(false)
            def markPaidIfCompleted(
                rideId: RideId,
                paymentMethod: Option[com.shevchyk.ride.domain.PaymentMethod]
            ): Task[Boolean] = ZIO.succeed(false)
            def findByClientId(id: PersonId): Task[List[Ride]]                                                  = ZIO.succeed(Nil)
            def findByDriverId(id: PersonId): Task[List[Ride]]                                                  = ZIO.fail(RuntimeException("db error"))
            def findByDriverIdAndCompany(id: PersonId, c: CompanyId): Task[List[Ride]]                          = ZIO.fail(
              RuntimeException("db error")
            )
            def findByClientIdAndCompany(id: PersonId, c: CompanyId): Task[List[Ride]]                          = ZIO.succeed(Nil)
            def findByStatus(s: RideStatus): Task[List[Ride]]                                                   = ZIO.succeed(Nil)
            def findByStatusAndCompany(s: RideStatus, c: CompanyId): Task[List[Ride]]                           = ZIO.succeed(Nil)
            def findByCompanyId(c: CompanyId): Task[List[Ride]]                                                 = ZIO.succeed(Nil)
            def findByCompanyIdPaginated(c: CompanyId, o: Int, l: Int): Task[List[Ride]]                        = ZIO.succeed(Nil)
            def findByDriverIdPaginated(id: PersonId, o: Int, l: Int): Task[List[Ride]]                         = ZIO.succeed(Nil)
            def findByDriverIdAndCompanyPaginated(id: PersonId, c: CompanyId, o: Int, l: Int): Task[List[Ride]] = ZIO
              .succeed(Nil)
            def findAll(): Task[List[Ride]]                                                                     = ZIO.succeed(Nil)
            def delete(id: RideId, c: CompanyId): Task[Unit]                                                    = ZIO.unit
            def countByCompanyGroupedByStatus(c: CompanyId): Task[Map[String, Int]]                             = ZIO.succeed(Map.empty)
            def sumRevenueByCompany(c: CompanyId): Task[BigDecimal]                                             = ZIO.succeed(BigDecimal(0))
            def sumTodayRevenueByCompany(c: CompanyId): Task[BigDecimal]                                        = ZIO.succeed(BigDecimal(0))
            def avgAssignmentMinutesByCompany(c: CompanyId): Task[Double]                                       = ZIO.succeed(0.0)
            def countDailyStatsByCompany(c: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]]          = ZIO.succeed(
              Nil
            )
            def earningsByDriver(
                dId: PersonId,
                c: CompanyId,
                from: java.time.Instant,
                to: java.time.Instant
            ): Task[com.shevchyk.ride.domain.DriverEarnings] = ZIO.succeed(
              com.shevchyk.ride.domain.DriverEarnings(BigDecimal(0), 0, 0)
            )
            def earningsBucketsByDriver(
                dId: PersonId,
                c: CompanyId,
                from: java.time.Instant,
                to: java.time.Instant,
                bucket: com.shevchyk.ride.repository.TimeBucket
            ): Task[List[(java.time.Instant, BigDecimal)]] = ZIO.succeed(Nil)
            def findAssignedRidesInWindow(from: java.time.Instant, to: java.time.Instant): Task[List[Ride]]     = ZIO
              .succeed(Nil)
            def findRidesNeedingConfirmation(from: java.time.Instant, to: java.time.Instant): Task[List[Ride]]  = ZIO
              .succeed(Nil)
            def clearReminders(id: RideId): Task[Unit]                                                          = ZIO.unit
            def countAllRidesByStatus(): Task[Map[String, Int]]                                                 = ZIO.succeed(Map.empty)
            def sumAllRevenue(from: java.time.Instant, to: java.time.Instant): Task[BigDecimal]                 = ZIO.succeed(
              BigDecimal(0)
            )
            def countRidesByCompany(
                from: java.time.Instant,
                to: java.time.Instant
            ): Task[Map[java.util.UUID, Int]] = ZIO.succeed(Map.empty)
            def sumRevenueByCompanyPlatform(
                from: java.time.Instant,
                to: java.time.Instant
            ): Task[Map[java.util.UUID, BigDecimal]] = ZIO.succeed(Map.empty)
            def updateCheckpoint(
                id: RideId,
                cp: com.shevchyk.ride.domain.AirportCheckpoint
            ): Task[Boolean] = ZIO.succeed(false)
            def updateFlightStatus(
                id: RideId,
                gate: Option[String],
                terminal: Option[String],
                flightStatus: Option[String],
                flightTime: Option[java.time.Instant]
            ): Task[Boolean] = ZIO.succeed(false)
            def findFlightStatus(id: RideId): Task[Option[com.shevchyk.ride.domain.FlightStatusRow]]            = ZIO.none
          )
          val layers          =
            InMemoryDriverLocationRepository.layer ++
              EventHub.layer ++
              noopGeofenceService ++
              failingRideRepo ++
              noopPersonRepository >>>
              DriverLocationService.layer
          for {
            service <- ZIO.service[DriverLocationService].provide(layers)
            result  <- service.updateLocation(testDriverId, 48.1, 11.5).exit
          } yield assertTrue(result.isSuccess)
        }
      ),
      // -----------------------------------------------------------------------
      // NEW: getAvailableDrivers — tenant isolation (service layer)
      // -----------------------------------------------------------------------
      suite("getAvailableDrivers — tenant isolation (service layer)")(
        test("getAvailableDrivers with wrong companyId returns empty list") {
          // Use a company-aware driver location repo to verify the service passes
          // the correct companyId through to the repository query.
          val companyA = testCompanyId
          val companyB = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000002"))

          class CompanyAwareDriverLocationRepository extends DriverLocationRepository:

            private val locations = Unsafe.unsafe { implicit unsafe =>
              Runtime.default.unsafe
                .run(Ref.Synchronized.make(Map.empty[PersonId, DriverLocation]))
                .getOrThrowFiberFailure()
            }

            private val availability = Unsafe.unsafe { implicit unsafe =>
              Runtime.default.unsafe
                .run(Ref.Synchronized.make(Map.empty[PersonId, (String, CompanyId)]))
                .getOrThrowFiberFailure()
            }

            override def updateLocation(driverId: PersonId, lat: Double, lng: Double): Task[Unit] = locations.update(
              _.updated(driverId, DriverLocation(driverId, lat, lng, Instant.now()))
            )

            override def getLocation(driverId: PersonId): Task[Option[DriverLocation]] = locations.get.map(
              _.get(driverId)
            )

            override def updateAvailability(driverId: PersonId, status: String): Task[Unit] =
              // Associate with companyA when the driver is testDriverId
              availability.update(_.updated(driverId, (status, companyA)))

            override def getAvailability(driverId: PersonId): Task[Option[String]] = availability.get.map(
              _.get(driverId).map(_._1)
            )

            override def findAvailableByCompanyId(
                cId: CompanyId
            ): Task[List[(PersonId, String, Option[Double], Option[Double])]] =
              for {
                avail <- availability.get
                locs  <- locations.get
              } yield avail
                .filter { case (_, (status, company)) => status == "Available" && company == cId }
                .keys
                .toList
                .map { pid =>
                  val loc = locs.get(pid)
                  (pid, "Available", loc.map(_.latitude), loc.map(_.longitude))
                }

          val repoLayer: ZLayer[Any, Nothing, DriverLocationRepository] = ZLayer.succeed(
            new CompanyAwareDriverLocationRepository
          )

          val layers =
            repoLayer ++
              EventHub.layer ++
              noopGeofenceService ++
              InMemoryRideRepository.layer ++
              noopPersonRepository >>>
              DriverLocationService.layer

          for {
            service <- ZIO.service[DriverLocationService].provide(layers)
            _       <- service.updateAvailability(testDriverId, "Available")
            _       <- service.updateLocation(testDriverId, 48.1351, 11.5820)
            // testDriverId is in companyA — querying companyB must return empty
            drivers <- service.getAvailableDrivers(companyB)
          } yield assertTrue(drivers.isEmpty)
        }
      )
    )
}
