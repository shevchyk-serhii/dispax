package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*
import zio.test.*
import java.time.Instant

object BlacklistRepositorySpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId.generate()
  val otherCompanyId = CompanyId.generate()
  val clientId1      = PersonId.generate()
  val clientId2      = PersonId.generate()
  val driverId1      = PersonId.generate()
  val driverId2      = PersonId.generate()
  val createdBy      = PersonId.generate()

  def makeEntry(
      companyId: CompanyId = testCompanyId,
      clientId: PersonId = clientId1,
      driverId: PersonId = driverId1,
      reason: Option[String] = Some("test reason"),
      isActive: Boolean = true
  ): BlacklistEntry = BlacklistEntry(
    id = BlacklistEntryId.generate(),
    companyId = companyId,
    clientId = clientId,
    driverId = driverId,
    reason = reason,
    createdBy = createdBy,
    createdAt = Instant.now(),
    isActive = isActive
  )

  val layers = BlacklistRepository.inMemory

  def spec =
    suite("BlacklistRepository")(
      suite("create and findByCompanyId")(
        test("creates entry and finds by company") {
          val entry = makeEntry()
          for {
            repo    <- ZIO.service[BlacklistRepository]
            created <- repo.create(entry)
            found   <- repo.findByCompanyId(testCompanyId)
          } yield assertTrue(
            created.id == entry.id &&
              found.size == 1 &&
              found.head.id == entry.id &&
              found.head.companyId == testCompanyId &&
              found.head.clientId == clientId1 &&
              found.head.driverId == driverId1
          )
        }.provide(layers),
        test("returns empty for unknown company") {
          val entry = makeEntry()
          for {
            repo  <- ZIO.service[BlacklistRepository]
            _     <- repo.create(entry)
            found <- repo.findByCompanyId(otherCompanyId)
          } yield assertTrue(found.isEmpty)
        }.provide(layers)
      ),
      suite("isBlacklisted")(
        test("returns true for existing blacklist pair") {
          val entry = makeEntry()
          for {
            repo   <- ZIO.service[BlacklistRepository]
            _      <- repo.create(entry)
            result <- repo.isBlacklisted(clientId1, driverId1)
          } yield assertTrue(result)
        }.provide(layers),
        test("returns false for non-blacklisted pair") {
          for {
            repo   <- ZIO.service[BlacklistRepository]
            _      <- repo.create(makeEntry(clientId = clientId1, driverId = driverId1))
            result <- repo.isBlacklisted(clientId2, driverId2)
          } yield assertTrue(!result)
        }.provide(layers),
        test("returns false after deactivation") {
          val entry = makeEntry()
          for {
            repo   <- ZIO.service[BlacklistRepository]
            _      <- repo.create(entry)
            before <- repo.isBlacklisted(clientId1, driverId1)
            _      <- repo.deactivate(entry.id, testCompanyId)
            after  <- repo.isBlacklisted(clientId1, driverId1)
          } yield assertTrue(before && !after)
        }.provide(layers)
      ),
      suite("deactivate")(
        test("deactivates entry successfully") {
          val entry = makeEntry()
          for {
            repo   <- ZIO.service[BlacklistRepository]
            _      <- repo.create(entry)
            cross  <- repo.deactivate(entry.id, otherCompanyId) // cross-tenant: no-op
            result <- repo.deactivate(entry.id, testCompanyId)
            found  <- repo.findByCompanyId(testCompanyId)
          } yield assertTrue(!cross && result && found.isEmpty)
        }.provide(layers),
        test("returns false for unknown id") {
          for {
            repo   <- ZIO.service[BlacklistRepository]
            result <- repo.deactivate(BlacklistEntryId.generate(), testCompanyId)
          } yield assertTrue(!result)
        }.provide(layers)
      ),
      suite("findByClientId and findByDriverId")(
        test("filters by client ID") {
          val entry1 = makeEntry(clientId = clientId1, driverId = driverId1)
          val entry2 = makeEntry(clientId = clientId2, driverId = driverId2)
          for {
            repo  <- ZIO.service[BlacklistRepository]
            _     <- repo.create(entry1)
            _     <- repo.create(entry2)
            found <- repo.findByClientId(clientId1)
          } yield assertTrue(
            found.size == 1 &&
              found.head.clientId == clientId1
          )
        }.provide(layers),
        test("filters by driver ID") {
          val entry1 = makeEntry(clientId = clientId1, driverId = driverId1)
          val entry2 = makeEntry(clientId = clientId2, driverId = driverId2)
          for {
            repo  <- ZIO.service[BlacklistRepository]
            _     <- repo.create(entry1)
            _     <- repo.create(entry2)
            found <- repo.findByDriverId(driverId2)
          } yield assertTrue(
            found.size == 1 &&
              found.head.driverId == driverId2
          )
        }.provide(layers)
      )
    )
}
