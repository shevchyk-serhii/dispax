package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.PostgresChatMessageRepository
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import zio.test.*

import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

/**
 * Integration tests for PostgresChatMessageRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresChatMessageRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000040-0000-0000-0000-000000000001"))
  val clientId      = PersonId(UUID.fromString("00000041-0000-0000-0000-000000000001"))
  val driverId      = PersonId(UUID.fromString("00000041-0000-0000-0000-000000000002"))
  val rideId1       = RideId(UUID.fromString("00000042-0000-0000-0000-000000000001"))
  val rideId2       = RideId(UUID.fromString("00000042-0000-0000-0000-000000000002"))

  private def seedRide(xa: Transactor[Task], rid: RideId): Task[Unit] =
    sql"""INSERT INTO rides (id, client_id, creator_id, company_id, status,
            from_address, to_address, pickup_datetime, request_time)
            VALUES (${rid.value}, ${clientId.value}, ${clientId.value}, ${testCompanyId.value}, 'Requested',
            'A', 'B', NOW(), NOW())
            ON CONFLICT DO NOTHING""".update.run.transact(xa).unit

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Chat GmbH', 'chat-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientId.value}, 'Chat Client', 'chat-client@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverId.value}, 'Chat Driver', 'chat-driver@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa) *> seedRide(xa, rideId1) *> seedRide(xa, rideId2)

  private def cleanMessages(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM chat_messages".update.run.transact(xa).unit

  private def makeMessage(
      ride: RideId,
      sender: PersonId = clientId,
      text: String = "hello",
      sentAt: Instant = Instant.now().truncatedTo(ChronoUnit.MICROS)
  ): ChatMessage = ChatMessage(
    id = ChatMessageId(UUID.randomUUID()),
    rideId = ride,
    senderId = sender,
    message = text,
    sentAt = sentAt
  )

  def spec =
    suite("PostgresChatMessageRepository")(
      test("save and findByRideId round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanMessages(xa)
          repo   = PostgresChatMessageRepository(xa)
          msg    = makeMessage(rideId1, sender = driverId, text = "on my way")
          _     <- repo.save(msg)
          found <- repo.findByRideId(rideId1)
        } yield assertTrue(
          found.length == 1,
          found.head.id == msg.id,
          found.head.rideId == rideId1,
          found.head.senderId == driverId,
          found.head.message == "on my way"
        )
      },
      test("findByRideId isolates by ride and orders by sent_at ASC") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanMessages(xa)
          repo   = PostgresChatMessageRepository(xa)
          base   = Instant.parse("2026-05-01T10:00:00Z")
          m1     = makeMessage(rideId1, text = "first", sentAt = base)
          m2     = makeMessage(rideId1, text = "second", sentAt = base.plusSeconds(60))
          m3     = makeMessage(rideId1, text = "third", sentAt = base.plusSeconds(120))
          other  = makeMessage(rideId2, text = "other ride")
          // save out of order to prove ORDER BY
          _     <- repo.save(m2)
          _     <- repo.save(m3)
          _     <- repo.save(m1)
          _     <- repo.save(other)
          ride1 <- repo.findByRideId(rideId1)
          ride2 <- repo.findByRideId(rideId2)
        } yield assertTrue(
          ride1.length == 3,
          ride1.map(_.message) == List("first", "second", "third"),
          ride2.length == 1,
          ride2.head.message == "other ride"
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
