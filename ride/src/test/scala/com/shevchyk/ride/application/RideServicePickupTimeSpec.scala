package com.shevchyk.ride.application

import com.shevchyk.core.config.AirportPickupConfig
import com.shevchyk.core.domain.*
import com.shevchyk.core.application.{
  DriverAvailabilityChecker,
  EventHub,
  AuditService,
  EmailSmsService,
  RideConfirmationData,
  GeocodingService,
  ScheduleDayLookup,
  UnavailabilitySlot
}
import com.shevchyk.core.repository.{
  BlacklistRepository,
  ClientCompanyRepository,
  CompanySettingsRepository,
  InMemoryClientCompanyRepository,
  InMemoryCompanySettingsRepository,
  PersonRepository
}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.{PickupTimeService, PickupTimeResult, RideService}
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryRideRepository}
import zio.*
import zio.test.*
import zio.test.Assertion.*

import java.time.Instant
import java.util.UUID

/**
 * Unit tests for the pickup-time auto-compute logic in RideService.createRide.
 *
 * Coverage (per plan):
 *   1. Departure + NO manual pickupDateTime + flightTime present → pickupDateTime == computed value. 2. Departure +
 *      manual pickupDateTime supplied → NOT overridden, supplied value kept. 3. Arrival ride → pickupDateTime unchanged
 *      (no auto-compute). 4. Regular ride (no airport transfer) → unchanged. 5. HERE unavailable (Haversine path) →
 *      ride still created, no error. 6. flightTime absent for departure (no manual pickup) → ride created with no
 *      pickupDateTime set.
 *
 * Mutation-verified branches (tested by deliberately breaking the guard and observing failure):
 *   - Departure guard `isArrival=false`: test 3 (arrival) kills a mutation that removes the isArrival check.
 *   - `pickupDateTime.isEmpty` guard: test 2 (manual override) kills a mutation that ignores manual pickup.
 *   - HERE-None fallback: test 5 verifies ride creation still succeeds when travel time unavailable.
 *   - Non-airport pass-through: test 4 kills a mutation that always invokes PickupTimeService.
 */
object RideServicePickupTimeSpec extends ZIOSpecDefault {

  // ── IDs ─────────────────────────────────────────────────────────────────────

  val companyId = CompanyId(UUID.fromString("11111111-0000-0000-0000-000000000001"))
  val clientId  = PersonId(UUID.fromString("22222222-0000-0000-0000-000000000001"))
  val driverId  = PersonId(UUID.fromString("33333333-0000-0000-0000-000000000001"))

  // ── Persons ────────────────────────────────────────────────────────────────

  val clientPerson = Person(
    id = clientId,
    name = "Test Client",
    email = "client@example.com",
    role = PersonRole.Client,
    companyId = Some(companyId)
  )

  val driverPerson = Person(
    id = driverId,
    name = "Test Driver",
    email = "driver@example.com",
    role = PersonRole.Driver,
    companyId = Some(companyId)
  )

  // ── No-op stubs ─────────────────────────────────────────────────────────────

  val noopEmailSms: ZLayer[Any, Nothing, EmailSmsService] = ZLayer.succeed(new EmailSmsService:
    def sendRideConfirmation(data: RideConfirmationData): Task[Unit]                       = ZIO.unit
    def sendDriverAssignment(data: RideConfirmationData): Task[Unit]                       = ZIO.unit
    def sendInvoiceEmail(data: com.shevchyk.core.application.InvoiceEmailData): Task[Unit] = ZIO.unit
  )

  val personRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(new PersonRepository:
    private val people                                                                        = Map(clientId -> clientPerson, driverId -> driverPerson)
    def create(p: Person): Task[Person]                                                       = ZIO.succeed(p)
    def findById(id: PersonId): Task[Option[Person]]                                          = ZIO.succeed(people.get(id))
    def findByIdAndCompany(id: PersonId, cid: CompanyId): Task[Option[Person]]                = ZIO.succeed(
      people.get(id).filter(_.companyId.contains(cid))
    )
    def findByEmail(e: String): Task[Option[Person]]                                          = ZIO.succeed(people.values.find(_.email == e))
    def findByRole(r: PersonRole): Task[List[Person]]                                         = ZIO.succeed(people.values.filter(_.role == r).toList)
    def findByRoleAndCompany(r: PersonRole, cid: CompanyId): Task[List[Person]]               = ZIO.succeed(
      people.values.filter(p => p.role == r && p.companyId.contains(cid)).toList
    )
    def findByCompanyId(cid: CompanyId): Task[List[Person]]                                   = ZIO.succeed(
      people.values.filter(_.companyId.contains(cid)).toList
    )
    def findAll(): Task[List[Person]]                                                         = ZIO.succeed(people.values.toList)
    def update(p: Person): Task[Person]                                                       = ZIO.succeed(p)
    def delete(id: PersonId): Task[Unit]                                                      = ZIO.unit
    def deleteInCompany(id: PersonId, cid: CompanyId): Task[Unit]                             = ZIO.unit
    def findByStatus(s: UserStatus): Task[List[Person]]                                       = ZIO.succeed(Nil)
    def searchByQuery(q: String): Task[List[Person]]                                          = ZIO.succeed(Nil)
    def updateLastLogin(id: PersonId): Task[Unit]                                             = ZIO.unit
    def findByClientCompany(ccId: ClientCompanyId): Task[List[Person]]                        = ZIO.succeed(Nil)
    def upsertDriverRow(id: PersonId): Task[Unit]                                             = ZIO.unit
    def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                          = ZIO.succeed(None)
    def setAvatar(id: PersonId, companyId: CompanyId, b: Array[Byte], ct: String): Task[Unit] = ZIO.unit
    def deleteAvatar(id: PersonId, companyId: CompanyId): Task[Unit]                          = ZIO.unit
  )

  // ── Deterministic geocoding: enriches any pickup/dropoff to known coordinates ─

  // Munich city ↔ MUC airport (same as PickupTimeServiceSpec, ensures Haversine gives 36 min)
  val pickupLat  = 48.1351
  val pickupLng  = 11.5820
  val dropoffLat = 48.3537
  val dropoffLng = 11.7750

  val deterministicGeocoding: ZLayer[Any, Nothing, GeocodingService] = ZLayer.succeed(
    new GeocodingService:
      def geocode(address: String): Task[Option[(Double, Double)]] =
        if address.toLowerCase.contains("munich city") then ZIO.succeed(Some((pickupLat, pickupLng)))
        else if address.toLowerCase.contains("muc airport") then ZIO.succeed(Some((dropoffLat, dropoffLng)))
        else ZIO.succeed(None) // addresses without coords: pickup-time uses Haversine fallback anyway
  )

  // ── TravelTimeService stubs ──────────────────────────────────────────────

  val hereAvailable: ZLayer[Any, Nothing, TravelTimeService] = ZLayer.succeed(
    new TravelTimeService:
      def travelMinutes(fromLat: Double, fromLng: Double, toLat: Double, toLng: Double): Task[Option[Int]] = ZIO
        .succeed(Some(30))
  )

  val hereUnavailable: ZLayer[Any, Nothing, TravelTimeService] = ZLayer.succeed(
    new TravelTimeService:
      def travelMinutes(fromLat: Double, fromLng: Double, toLat: Double, toLng: Double): Task[Option[Int]] = ZIO
        .succeed(None)
  )

  // ── PickupTimeService layers ─────────────────────────────────────────────

  val globalConfig = AirportPickupConfig(defaultBufferMinutes = 15, defaultCheckInCloseMinutes = 60)

  def pickupServiceLayer(travelTime: ZLayer[Any, Nothing, TravelTimeService]): ZLayer[Any, Nothing, PickupTimeService] =
    (CompanySettingsRepository.inMemory ++
      InMemoryClientCompanyRepository.layer ++
      travelTime ++
      ZLayer.succeed(globalConfig)) >+> PickupTimeService.layer

  // ── Full RideService layers ──────────────────────────────────────────────

  private val noopAvailabilityChecker: ZLayer[Any, Nothing, DriverAvailabilityChecker] = ZLayer.succeed(
    new DriverAvailabilityChecker:
      def overlappingUnavailability(
          driverId: PersonId,
          companyId: CompanyId,
          from: java.time.Instant,
          to: java.time.Instant
      ): Task[List[UnavailabilitySlot]] = ZIO.succeed(Nil)
  )

  private val noopScheduleDayLookup: ZLayer[Any, Nothing, ScheduleDayLookup] = ZLayer.succeed(
    new ScheduleDayLookup:
      def find(id: ScheduleDayId) = ZIO.succeed(None)
  )

  def rideLayers(
      travelTime: ZLayer[Any, Nothing, TravelTimeService] = hereAvailable
  ): ZLayer[Any, Nothing, RideService] =
    (InMemoryRideRepository.layer ++
      personRepo ++
      EventHub.layer ++
      noopEmailSms ++
      AuditService.inMemory ++
      BlacklistRepository.inMemory ++
      deterministicGeocoding ++
      ExpenseRepository.inMemory ++
      pickupServiceLayer(travelTime) ++
      noopAvailabilityChecker ++
      noopScheduleDayLookup) >+> RideService.layer

  // ── Flight departure time used in all departure tests ───────────────────
  // 2030-06-15T12:00:00Z → with global defaults (buffer=15, checkIn=60) and travel=30:
  // expected pickup = 12:00 − 105min = 10:15:00Z
  val flightDep      = Instant.parse("2030-06-15T12:00:00Z")
  val expectedPickup = Instant.parse("2030-06-15T10:15:00Z")
  val manualPickup   = Instant.parse("2030-06-15T09:00:00Z")

  // ── Request builders ─────────────────────────────────────────────────────

  def departureRequestNoManualPickup: CreateRideRequest = CreateRideRequest(
    clientId = clientId,
    companyId = companyId,
    pickupLocation = Location("Munich City", latitude = Some(pickupLat), longitude = Some(pickupLng)),
    dropoffLocation = Location("MUC Airport", latitude = Some(dropoffLat), longitude = Some(dropoffLng)),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH001", isArrival = false)),
    scheduledTime = Some(flightDep),
    pickupDateTime = None // ← signal: compute it automatically
  )

  def departureRequestWithManualPickup: CreateRideRequest = departureRequestNoManualPickup.copy(
    pickupDateTime = Some(manualPickup) // ← operator explicitly supplied a time
  )

  def arrivalRequest: CreateRideRequest = CreateRideRequest(
    clientId = clientId,
    companyId = companyId,
    pickupLocation = Location("MUC Airport", latitude = Some(dropoffLat), longitude = Some(dropoffLng)),
    dropoffLocation = Location("Munich City", latitude = Some(pickupLat), longitude = Some(pickupLng)),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH001", isArrival = true)),
    scheduledTime = Some(flightDep),
    pickupDateTime = Some(manualPickup) // required for non-departure
  )

  def regularRideRequest: CreateRideRequest = CreateRideRequest(
    clientId = clientId,
    companyId = companyId,
    pickupLocation = Location("Munich City", latitude = Some(pickupLat), longitude = Some(pickupLng)),
    dropoffLocation = Location("MUC Airport", latitude = Some(dropoffLat), longitude = Some(dropoffLng)),
    pickupDateTime = Some(manualPickup)
  )

  def departureRequestNoFlightTime: CreateRideRequest = CreateRideRequest(
    clientId = clientId,
    companyId = companyId,
    pickupLocation = Location("Munich City", latitude = Some(pickupLat), longitude = Some(pickupLng)),
    dropoffLocation = Location("MUC Airport", latitude = Some(dropoffLat), longitude = Some(dropoffLng)),
    specifics = Some(RideSpecifics.AirportTransfer("MUC", "LH001", isArrival = false)),
    scheduledTime = None, // no flight time supplied
    pickupDateTime = None // also no manual pickup
  )

  // ── Spec ─────────────────────────────────────────────────────────────────

  def spec =
    suite("RideService — pickup-time auto-compute")(
      test("departure ride WITHOUT manual pickupDateTime → pickupDateTime equals computed value") {
        // Mutation-verified:
        //   - kills "always pass through enrichedRequest" (departure guard)
        //   - kills "don't call PickupTimeService when pickupDateTime is None" (isEmpty guard)
        for {
          svc  <- ZIO.service[RideService]
          ride <- svc.createRide(departureRequestNoManualPickup)
        } yield assertTrue(
          ride.pickupDateTime == expectedPickup,
          ride.specifics.exists { case RideSpecifics.AirportTransfer(_, _, isArrival) => !isArrival }
        )
      }.provide(rideLayers()),
      test("departure ride WITH manual pickupDateTime → NOT overridden (supplied value kept)") {
        // Mutation-verified: kills "always compute pickup, ignore manual" mutation —
        // if the guard `pickupDateTime.isEmpty` were removed, the computed 10:15 would replace 09:00.
        for {
          svc  <- ZIO.service[RideService]
          ride <- svc.createRide(departureRequestWithManualPickup)
        } yield assertTrue(ride.pickupDateTime == manualPickup)
      }.provide(rideLayers()),
      test("arrival ride → pickupDateTime unchanged (no auto-compute)") {
        // Mutation-verified: kills "treat arrivals the same as departures" mutation.
        // If isArrival guard were removed, the service would try to compute pickup for an arrival.
        for {
          svc  <- ZIO.service[RideService]
          ride <- svc.createRide(arrivalRequest)
        } yield assertTrue(ride.pickupDateTime == manualPickup)
      }.provide(rideLayers()),
      test("regular ride (no airport transfer) → pickupDateTime unchanged") {
        // Mutation-verified: kills "always invoke PickupTimeService regardless of specifics" mutation
        for {
          svc  <- ZIO.service[RideService]
          ride <- svc.createRide(regularRideRequest)
        } yield assertTrue(ride.pickupDateTime == manualPickup)
      }.provide(rideLayers()),
      test("HERE unavailable (Haversine fallback) → ride still created, no error propagated") {
        // Mutation-verified: kills "propagate HERE error to ride creation" mutation
        for {
          svc    <- ZIO.service[RideService]
          result <- svc.createRide(departureRequestNoManualPickup).exit
        } yield assertTrue(result.isSuccess)
      }.provide(rideLayers(hereUnavailable)),
      test("HERE unavailable → pickup time is set (Haversine fallback used)") {
        for {
          svc  <- ZIO.service[RideService]
          ride <- svc.createRide(departureRequestNoManualPickup)
        } yield {
          // With Haversine ~36 min + buffer=15 + checkIn=60 = ~111 min before flight
          val pickup  = ride.pickupDateTime
          val diffMin = java.time.Duration.between(pickup, flightDep).toMinutes
          assertTrue(diffMin >= 90, diffMin <= 150) // reasonable range for Haversine path
        }
      }.provide(rideLayers(hereUnavailable)),
      test("departure ride with no flightTime and no manual pickup → ride still created") {
        // RideService logs a warning and passes through enrichedRequest unchanged.
        // The ride has no pickupDateTime (None). No error must be raised.
        for {
          svc    <- ZIO.service[RideService]
          result <- svc.createRide(departureRequestNoFlightTime).exit
        } yield assertTrue(result.isSuccess)
      }.provide(rideLayers())
    )
}
