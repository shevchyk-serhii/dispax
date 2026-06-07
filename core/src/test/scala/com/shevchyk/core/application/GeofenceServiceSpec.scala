package com.shevchyk.core.application

import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.GeofenceRepository
import zio.*
import zio.test.*
import java.util.UUID

object GeofenceServiceSpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val otherCompanyId = CompanyId(UUID.fromString("00000002-0000-0000-0000-000000000002"))
  val testDriverId   = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000001"))

  // Munich Airport coordinates
  val airportLat = 48.3537
  val airportLng = 11.7751

  // Point inside 1000m radius of Munich Airport (~500m away)
  val insideLat = 48.3580
  val insideLng = 11.7751

  // Point outside 1000m radius (~5km away)
  val outsideLat = 48.40
  val outsideLng = 11.80

  val layers = (GeofenceRepository.inMemory ++ EventHub.layer) >+> GeofenceService.layer

  def createGeofence(
      repo: GeofenceRepository,
      name: String = "Munich Airport",
      companyId: CompanyId = testCompanyId,
      lat: Double = airportLat,
      lng: Double = airportLng,
      radius: Int = 1000,
      notifyOnEntry: Boolean = true,
      notifyOnExit: Boolean = false,
      isActive: Boolean = true
  ): Task[Geofence] = repo.create(
    Geofence(
      id = GeofenceId(UUID.randomUUID()),
      companyId = companyId,
      name = name,
      geofenceType = GeofenceType.Airport,
      centerLatitude = lat,
      centerLongitude = lng,
      radiusMeters = radius,
      isActive = isActive,
      notifyOnEntry = notifyOnEntry,
      notifyOnExit = notifyOnExit
    )
  )

  def spec =
    suite("GeofenceService")(
      suite("checkDriverLocation")(
        test("empty when no geofences") {
          for {
            service <- ZIO.service[GeofenceService]
            alerts  <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
          } yield assertTrue(alerts.isEmpty)
        }.provide(layers),
        test("entry alert when inside radius") {
          for {
            repo    <- ZIO.service[GeofenceRepository]
            _       <- createGeofence(repo)
            service <- ZIO.service[GeofenceService]
            alerts  <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
          } yield assertTrue(
            alerts.size == 1 &&
              alerts.head.alertType == "entry" &&
              alerts.head.geofenceName == "Munich Airport"
          )
        }.provide(layers),
        test("no alert when notifyOnEntry is false") {
          for {
            repo    <- ZIO.service[GeofenceRepository]
            _       <- createGeofence(repo, notifyOnEntry = false)
            service <- ZIO.service[GeofenceService]
            alerts  <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
          } yield assertTrue(alerts.isEmpty)
        }.provide(layers),
        test("exit alert when leaving geofence") {
          for {
            repo    <- ZIO.service[GeofenceRepository]
            _       <- createGeofence(repo, notifyOnExit = true)
            service <- ZIO.service[GeofenceService]
            // First enter the geofence
            _       <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
            // Then leave
            alerts  <- service.checkDriverLocation(testDriverId, testCompanyId, outsideLat, outsideLng)
          } yield assertTrue(
            alerts.size == 1 &&
              alerts.head.alertType == "exit"
          )
        }.provide(layers),
        test("no duplicate entries on second call at same location") {
          for {
            repo    <- ZIO.service[GeofenceRepository]
            _       <- createGeofence(repo)
            service <- ZIO.service[GeofenceService]
            alerts1 <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
            alerts2 <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
          } yield assertTrue(
            alerts1.size == 1 &&
              alerts2.isEmpty
          )
        }.provide(layers),
        test("handles multiple geofences") {
          for {
            repo    <- ZIO.service[GeofenceRepository]
            _       <- createGeofence(repo, name = "Zone A")
            _       <- createGeofence(repo, name = "Zone B", lat = insideLat, lng = insideLng, radius = 2000)
            service <- ZIO.service[GeofenceService]
            alerts  <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
          } yield assertTrue(alerts.size == 2)
        }.provide(layers),
        test("only checks company's geofences") {
          for {
            repo    <- ZIO.service[GeofenceRepository]
            _       <- createGeofence(repo, companyId = otherCompanyId)
            service <- ZIO.service[GeofenceService]
            alerts  <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
          } yield assertTrue(alerts.isEmpty)
        }.provide(layers),
        test("inactive geofence is ignored") {
          for {
            repo    <- ZIO.service[GeofenceRepository]
            _       <- createGeofence(repo, isActive = false)
            service <- ZIO.service[GeofenceService]
            alerts  <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
          } yield assertTrue(alerts.isEmpty)
        }.provide(layers),
        test("publishes GeofenceTriggered event on entry") {
          for {
            repo     <- ZIO.service[GeofenceRepository]
            _        <- createGeofence(repo)
            eventHub <- ZIO.service[EventHub]
            events   <- ZIO.scoped {
                          for {
                            dequeue <- eventHub.subscribe
                            service <- ZIO.service[GeofenceService]
                            _       <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
                            evts    <- dequeue.takeAll
                          } yield evts
                        }
            triggered = events.collect { case e: WebSocketEvent.GeofenceTriggered => e }
          } yield assertTrue(
            triggered.size == 1 &&
              triggered.head.alertType == "entry" &&
              triggered.head.driverId == testDriverId.value
          )
        }.provide(layers),
        test("publishes GeofenceTriggered event on exit") {
          for {
            repo      <- ZIO.service[GeofenceRepository]
            _         <- createGeofence(repo, notifyOnExit = true)
            eventHub  <- ZIO.service[EventHub]
            events    <- ZIO.scoped {
                           for {
                             dequeue <- eventHub.subscribe
                             service <- ZIO.service[GeofenceService]
                             _       <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
                             _       <- service.checkDriverLocation(testDriverId, testCompanyId, outsideLat, outsideLng)
                             evts    <- dequeue.takeAll
                           } yield evts
                         }
            exitEvents = events.collect { case e: WebSocketEvent.GeofenceTriggered if e.alertType == "exit" => e }
          } yield assertTrue(
            exitEvents.size == 1 &&
              exitEvents.head.geofenceName == "Munich Airport"
          )
        }.provide(layers),
        test("entry and exit both enabled on same geofence") {
          for {
            repo    <- ZIO.service[GeofenceRepository]
            _       <- createGeofence(repo, notifyOnEntry = true, notifyOnExit = true)
            service <- ZIO.service[GeofenceService]
            entry   <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
            exit    <- service.checkDriverLocation(testDriverId, testCompanyId, outsideLat, outsideLng)
          } yield assertTrue(
            entry.size == 1 && entry.head.alertType == "entry" &&
              exit.size == 1 && exit.head.alertType == "exit"
          )
        }.provide(layers),
        test("saves alert to repository") {
          for {
            repo    <- ZIO.service[GeofenceRepository]
            gf      <- createGeofence(repo)
            service <- ZIO.service[GeofenceService]
            _       <- service.checkDriverLocation(testDriverId, testCompanyId, insideLat, insideLng)
            saved   <- repo.findAlertsByDriver(testDriverId, 10)
          } yield assertTrue(saved.nonEmpty)
        }.provide(layers),
        // -- Edge case added by test audit 2026-06 -------------------------
        test("geofence with radius 0 never triggers, even at exact center") {
          // distance < radiusMeters is strict (<); a 0-radius geofence is degenerate and
          // must never report the driver as inside, including standing on the center.
          for {
            repo    <- ZIO.service[GeofenceRepository]
            _       <- createGeofence(repo, radius = 0)
            service <- ZIO.service[GeofenceService]
            alerts  <- service.checkDriverLocation(testDriverId, testCompanyId, airportLat, airportLng)
          } yield assertTrue(alerts.isEmpty)
        }.provide(layers)
      ),
      suite("checkClientProximity")(
        test("triggers proximity thresholds and publishes DriverApproaching events") {
          val rideId     = UUID.randomUUID()
          val activeRide = ActiveRideInfo(
            rideId = rideId,
            clientId = UUID.randomUUID(),
            pickupLatitude = Some(airportLat),
            pickupLongitude = Some(airportLng),
            companyId = testCompanyId.value
          )
          for {
            eventHub   <- ZIO.service[EventHub]
            events     <- ZIO.scoped {
                            for {
                              dequeue <- eventHub.subscribe
                              service <- ZIO.service[GeofenceService]
                              // Driver ~500m from pickup — should trigger 2km, 500m, and 100m thresholds
                              _       <- service.checkClientProximity(testDriverId, insideLat, insideLng, List(activeRide))
                              // Drain published events (non-blocking)
                              evts    <- dequeue.takeAll
                            } yield evts
                          }
            approaching = events.collect { case e: WebSocketEvent.DriverApproaching => e }
          } yield assertTrue(
            approaching.nonEmpty &&
              approaching.forall(_.rideId == rideId) &&
              approaching.forall(_.driverId == testDriverId.value)
          )
        }.provide(layers),
        test("no-op without pickup coordinates — no events published") {
          val activeRide = ActiveRideInfo(
            rideId = UUID.randomUUID(),
            clientId = UUID.randomUUID(),
            pickupLatitude = None,
            pickupLongitude = None,
            companyId = testCompanyId.value
          )
          for {
            eventHub <- ZIO.service[EventHub]
            events   <- ZIO.scoped {
                          for {
                            dequeue <- eventHub.subscribe
                            service <- ZIO.service[GeofenceService]
                            _       <- service.checkClientProximity(testDriverId, insideLat, insideLng, List(activeRide))
                            evts    <- dequeue.takeAll
                          } yield evts
                        }
          } yield assertTrue(events.isEmpty)
        }.provide(layers),
        test("no re-trigger for same threshold on second call") {
          val rideId     = UUID.randomUUID()
          val activeRide = ActiveRideInfo(
            rideId = rideId,
            clientId = UUID.randomUUID(),
            pickupLatitude = Some(insideLat),
            pickupLongitude = Some(insideLng),
            companyId = testCompanyId.value
          )
          for {
            service    <- ZIO.service[GeofenceService]
            eventHub   <- ZIO.service[EventHub]
            // First call triggers thresholds
            _          <- service.checkClientProximity(testDriverId, insideLat, insideLng, List(activeRide))
            // Second call at same location — subscribe only after first call
            events     <- ZIO.scoped {
                            for {
                              dequeue <- eventHub.subscribe
                              _       <- service.checkClientProximity(testDriverId, insideLat, insideLng, List(activeRide))
                              evts    <- dequeue.takeAll
                            } yield evts
                          }
            approaching = events.collect { case e: WebSocketEvent.DriverApproaching => e }
          } yield assertTrue(approaching.isEmpty)
        }.provide(layers),
        test("handles multiple rides") {
          val rides =
            (1 to 3).map { i =>
              ActiveRideInfo(
                rideId = UUID.randomUUID(),
                clientId = UUID.randomUUID(),
                pickupLatitude = Some(airportLat + i * 0.001),
                pickupLongitude = Some(airportLng),
                companyId = testCompanyId.value
              )
            }.toList
          for {
            eventHub     <- ZIO.service[EventHub]
            events       <- ZIO.scoped {
                              for {
                                dequeue <- eventHub.subscribe
                                service <- ZIO.service[GeofenceService]
                                _       <- service.checkClientProximity(testDriverId, insideLat, insideLng, rides)
                                evts    <- dequeue.takeAll
                              } yield evts
                            }
            approaching   = events.collect { case e: WebSocketEvent.DriverApproaching => e }
            distinctRides = approaching.map(_.rideId).toSet
          } yield assertTrue(approaching.nonEmpty && distinctRides.size >= 2)
        }.provide(layers),
        test("empty rides list is a no-op") {
          for {
            service <- ZIO.service[GeofenceService]
            _       <- service.checkClientProximity(testDriverId, insideLat, insideLng, List.empty)
          } yield assertCompletes
        }.provide(layers),
        test("triggers all thresholds when at exact pickup location") {
          val rideId     = UUID.randomUUID()
          val activeRide = ActiveRideInfo(
            rideId = rideId,
            clientId = UUID.randomUUID(),
            pickupLatitude = Some(insideLat),
            pickupLongitude = Some(insideLng),
            companyId = testCompanyId.value
          )
          for {
            eventHub  <- ZIO.service[EventHub]
            events    <- ZIO.scoped {
                           for {
                             dequeue <- eventHub.subscribe
                             service <- ZIO.service[GeofenceService]
                             // Driver at exact pickup (0m) — should trigger 2km, 500m, 100m
                             _       <- service.checkClientProximity(testDriverId, insideLat, insideLng, List(activeRide))
                             evts    <- dequeue.takeAll
                           } yield evts
                         }
            thresholds = events.collect { case e: WebSocketEvent.DriverApproaching => e.threshold }.toSet
          } yield assertTrue(
            thresholds.contains("2km") &&
              thresholds.contains("500m") &&
              thresholds.contains("100m")
          )
        }.provide(layers)
      )
    )
}
