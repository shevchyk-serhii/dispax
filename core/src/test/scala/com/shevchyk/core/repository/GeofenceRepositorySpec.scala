package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.test.*
import zio.*
import java.time.Instant
import java.util.UUID

object GeofenceRepositorySpec extends ZIOSpecDefault {

  val companyId      = CompanyId.generate()
  val otherCompanyId = CompanyId.generate()
  val driverId       = PersonId.generate()

  def makeGeofence(
      companyId: CompanyId = companyId,
      name: String = "Munich Airport",
      isActive: Boolean = true,
      geofenceType: GeofenceType = GeofenceType.Airport
  ): Geofence = Geofence(
    id = GeofenceId.generate(),
    companyId = companyId,
    name = name,
    geofenceType = geofenceType,
    centerLatitude = 48.353802,
    centerLongitude = 11.786085,
    radiusMeters = 1000,
    isActive = isActive
  )

  def makeAlert(geofence: Geofence, alertType: String = "entry"): GeofenceAlert = GeofenceAlert(
    id = UUID.randomUUID(),
    geofenceId = geofence.id,
    driverId = driverId,
    companyId = companyId,
    alertType = alertType,
    geofenceName = geofence.name,
    latitude = 48.35,
    longitude = 11.79,
    timestamp = Instant.now()
  )

  val layers = GeofenceRepository.inMemory

  def spec =
    suite("GeofenceRepository")(
      suite("create and findById")(
        test("creates and finds by id") {
          val g = makeGeofence()
          for {
            repo  <- ZIO.service[GeofenceRepository]
            _     <- repo.create(g)
            found <- repo.findById(g.id)
          } yield assertTrue(found.contains(g))
        }.provide(layers),
        test("returns None for unknown id") {
          for {
            repo  <- ZIO.service[GeofenceRepository]
            found <- repo.findById(GeofenceId.generate())
          } yield assertTrue(found.isEmpty)
        }.provide(layers)
      ),
      suite("findByCompanyId")(
        test("returns all geofences for company including inactive") {
          val active   = makeGeofence(isActive = true)
          val inactive = makeGeofence(isActive = false, name = "Inactive Zone")
          for {
            repo  <- ZIO.service[GeofenceRepository]
            _     <- repo.create(active)
            _     <- repo.create(inactive)
            found <- repo.findByCompanyId(companyId)
          } yield assertTrue(found.size == 2)
        }.provide(layers),
        test("returns empty for unknown company") {
          for {
            repo  <- ZIO.service[GeofenceRepository]
            _     <- repo.create(makeGeofence(companyId = companyId))
            found <- repo.findByCompanyId(otherCompanyId)
          } yield assertTrue(found.isEmpty)
        }.provide(layers)
      ),
      suite("findActiveByCompanyId")(
        test("returns only active geofences") {
          val active   = makeGeofence(isActive = true, name = "Active Zone")
          val inactive = makeGeofence(isActive = false, name = "Inactive Zone")
          for {
            repo  <- ZIO.service[GeofenceRepository]
            _     <- repo.create(active)
            _     <- repo.create(inactive)
            found <- repo.findActiveByCompanyId(companyId)
          } yield assertTrue(found.size == 1 && found.head.name == "Active Zone")
        }.provide(layers),
        test("returns empty when all geofences are inactive") {
          for {
            repo  <- ZIO.service[GeofenceRepository]
            _     <- repo.create(makeGeofence(isActive = false))
            found <- repo.findActiveByCompanyId(companyId)
          } yield assertTrue(found.isEmpty)
        }.provide(layers),
        test("does not mix companies") {
          for {
            repo  <- ZIO.service[GeofenceRepository]
            _     <- repo.create(makeGeofence(companyId = companyId, isActive = true))
            found <- repo.findActiveByCompanyId(otherCompanyId)
          } yield assertTrue(found.isEmpty)
        }.provide(layers)
      ),
      suite("update")(
        test("updates geofence fields") {
          val g       = makeGeofence(isActive = true)
          val updated = g.copy(isActive = false, name = "Updated Name")
          for {
            repo  <- ZIO.service[GeofenceRepository]
            _     <- repo.create(g)
            _     <- repo.update(updated)
            found <- repo.findById(g.id)
          } yield assertTrue(
            found.map(_.isActive).contains(false) &&
              found.map(_.name).contains("Updated Name")
          )
        }.provide(layers)
      ),
      suite("delete")(
        test("deletes existing geofence") {
          val g = makeGeofence()
          for {
            repo    <- ZIO.service[GeofenceRepository]
            _       <- repo.create(g)
            // Cross-tenant delete must not remove it.
            cross   <- repo.delete(g.id, CompanyId.generate())
            still   <- repo.findById(g.id)
            deleted <- repo.delete(g.id, companyId)
            found   <- repo.findById(g.id)
          } yield assertTrue(!cross && still.isDefined && deleted && found.isEmpty)
        }.provide(layers),
        test("returns false for unknown id") {
          for {
            repo    <- ZIO.service[GeofenceRepository]
            deleted <- repo.delete(GeofenceId.generate(), companyId)
          } yield assertTrue(!deleted)
        }.provide(layers)
      ),
      suite("saveAlert and findAlerts")(
        test("saves alert and finds by company") {
          val g     = makeGeofence()
          val alert = makeAlert(g, "entry")
          for {
            repo  <- ZIO.service[GeofenceRepository]
            _     <- repo.create(g)
            _     <- repo.saveAlert(alert)
            found <- repo.findAlertsByCompany(companyId, limit = 10)
          } yield assertTrue(found.size == 1 && found.head.alertType == "entry")
        }.provide(layers),
        test("finds alerts by driver") {
          val g     = makeGeofence()
          val alert = makeAlert(g, "exit")
          for {
            repo  <- ZIO.service[GeofenceRepository]
            _     <- repo.create(g)
            _     <- repo.saveAlert(alert)
            found <- repo.findAlertsByDriver(driverId, limit = 10)
          } yield assertTrue(found.size == 1 && found.head.alertType == "exit")
        }.provide(layers),
        test("respects limit parameter") {
          val g = makeGeofence()
          for {
            repo  <- ZIO.service[GeofenceRepository]
            _     <- repo.create(g)
            _     <- ZIO.foreach(1 to 5)(_ => repo.saveAlert(makeAlert(g)))
            found <- repo.findAlertsByCompany(companyId, limit = 3)
          } yield assertTrue(found.size == 3)
        }.provide(layers)
      )
    )
}
