package com.shevchyk.core.application

import com.shevchyk.core.domain.*
import zio.*
import zio.test.*
import java.time.Instant
import java.util.UUID

object AuditServiceSpec extends ZIOSpecDefault {

  val testCompanyId  = CompanyId.generate()
  val otherCompanyId = CompanyId.generate()
  val testActorId    = PersonId.generate()

  def makeEntry(
      companyId: CompanyId = testCompanyId,
      entityType: String = "Ride",
      entityId: UUID = UUID.randomUUID(),
      action: AuditAction = AuditAction.RideCreated,
      createdAt: Instant = Instant.now()
  ): AuditLogEntry = AuditLogEntry(
    id = AuditLogId.generate(),
    companyId = companyId,
    actorId = testActorId,
    action = action,
    entityType = entityType,
    entityId = entityId,
    createdAt = createdAt
  )

  val layers = AuditService.inMemory

  def spec =
    suite("AuditService")(
      suite("log and findByEntity")(
        test("logs entry and retrieves by entity type and id") {
          val entityId = UUID.randomUUID()
          val entry    = makeEntry(entityType = "Ride", entityId = entityId)
          for {
            service <- ZIO.service[AuditService]
            _       <- service.log(entry)
            found   <- service.findByEntity("Ride", entityId)
          } yield assertTrue(
            found.size == 1 &&
              found.head.id == entry.id &&
              found.head.entityType == "Ride" &&
              found.head.entityId == entityId
          )
        }.provide(layers),
        test("returns empty for unknown entity") {
          for {
            service <- ZIO.service[AuditService]
            found   <- service.findByEntity("Unknown", UUID.randomUUID())
          } yield assertTrue(found.isEmpty)
        }.provide(layers),
        test("multiple entries for same entity sorted by createdAt desc") {
          val entityId = UUID.randomUUID()
          val now      = Instant.now()
          val entry1   = makeEntry(entityType = "Ride", entityId = entityId, createdAt = now.minusSeconds(60))
          val entry2   = makeEntry(entityType = "Ride", entityId = entityId, createdAt = now.minusSeconds(30))
          val entry3   = makeEntry(entityType = "Ride", entityId = entityId, createdAt = now)
          for {
            service <- ZIO.service[AuditService]
            _       <- service.log(entry1)
            _       <- service.log(entry2)
            _       <- service.log(entry3)
            found   <- service.findByEntity("Ride", entityId)
          } yield assertTrue(
            found.size == 3 &&
              found(0).id == entry3.id &&
              found(1).id == entry2.id &&
              found(2).id == entry1.id
          )
        }.provide(layers)
      ),
      suite("findByCompany")(
        test("returns entries for company with limit and offset") {
          val now     = Instant.now()
          val entries = (0 until 5).map(i => makeEntry(createdAt = now.minusSeconds(i.toLong * 10)))
          for {
            service <- ZIO.service[AuditService]
            _       <- ZIO.foreach(entries)(service.log)
            found   <- service.findByCompany(testCompanyId, limit = 10, offset = 0)
          } yield assertTrue(
            found.size == 5 &&
              found.head.createdAt == now
          )
        }.provide(layers),
        test("respects pagination") {
          val now     = Instant.now()
          val entries = (0 until 5).map(i => makeEntry(createdAt = now.minusSeconds(i.toLong * 10)))
          for {
            service <- ZIO.service[AuditService]
            _       <- ZIO.foreach(entries)(service.log)
            page1   <- service.findByCompany(testCompanyId, limit = 2, offset = 0)
            page2   <- service.findByCompany(testCompanyId, limit = 2, offset = 2)
            page3   <- service.findByCompany(testCompanyId, limit = 2, offset = 4)
          } yield assertTrue(
            page1.size == 2 &&
              page2.size == 2 &&
              page3.size == 1
          )
        }.provide(layers),
        test("returns empty for unknown company") {
          for {
            service <- ZIO.service[AuditService]
            _       <- service.log(makeEntry())
            found   <- service.findByCompany(otherCompanyId, limit = 10, offset = 0)
          } yield assertTrue(found.isEmpty)
        }.provide(layers)
      )
    )
}
