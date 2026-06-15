package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.PostgresClientAddressRepository
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
 * Integration tests for PostgresClientAddressRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresClientAddressRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000030-0000-0000-0000-000000000001"))
  val clientId      = PersonId(UUID.fromString("00000031-0000-0000-0000-000000000001"))
  val otherClientId = PersonId(UUID.fromString("00000031-0000-0000-0000-000000000002"))

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Addr GmbH', 'addr-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientId.value}, 'Addr Client', 'addr-client@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${otherClientId.value}, 'Addr Client 2', 'addr-client2@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa)

  private def cleanAddresses(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM client_addresses".update.run.transact(xa).unit

  private def makeAddress(
      id: ClientAddressId = ClientAddressId.generate(),
      client: PersonId = clientId,
      label: String = "Home",
      address: String = "Marienplatz 1, Munich",
      useCount: Int = 1,
      aliases: List[String] = List("haus", "zuhause")
  ): ClientAddress = ClientAddress(
    id = id,
    clientId = client,
    label = label,
    address = address,
    latitude = Some(48.1374),
    longitude = Some(11.5755),
    useCount = useCount,
    aliases = aliases,
    createdAt = Instant.now().truncatedTo(ChronoUnit.MICROS),
    updatedAt = Instant.now().truncatedTo(ChronoUnit.MICROS)
  )

  def spec =
    suite("PostgresClientAddressRepository")(
      test("save and findByClient round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanAddresses(xa)
          repo   = PostgresClientAddressRepository(xa)
          addr   = makeAddress()
          _     <- repo.save(addr)
          found <- repo.findByClient(clientId)
        } yield assertTrue(
          found.length == 1,
          found.head.id == addr.id,
          found.head.label == "Home",
          found.head.address == "Marienplatz 1, Munich",
          found.head.latitude.contains(48.1374),
          found.head.longitude.contains(11.5755),
          found.head.aliases == List("haus", "zuhause")
        )
      },
      test("findByClient isolates by client and orders by use_count desc") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanAddresses(xa)
          repo   = PostgresClientAddressRepository(xa)
          low    = makeAddress(label = "Low", address = "Low St", useCount = 1)
          high   = makeAddress(label = "High", address = "High St", useCount = 9)
          _     <- repo.save(low)
          _     <- repo.save(high)
          _     <- repo.save(makeAddress(client = otherClientId, address = "Other St"))
          mine  <- repo.findByClient(clientId)
          other <- repo.findByClient(otherClientId)
        } yield assertTrue(
          mine.length == 2,
          mine.head.label == "High",
          mine.forall(_.clientId == clientId),
          other.length == 1
        )
      },
      test("incrementUseCount bumps the counter") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanAddresses(xa)
          repo   = PostgresClientAddressRepository(xa)
          addr   = makeAddress(useCount = 3)
          _     <- repo.save(addr)
          _     <- repo.incrementUseCount(addr.id)
          found <- repo.findByAddressText(clientId, addr.address)
        } yield assertTrue(
          found.isDefined,
          found.get.useCount == 4
        )
      },
      test("updateLabelAndAliases updates only provided fields, COALESCE keeps others") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanAddresses(xa)
          repo     = PostgresClientAddressRepository(xa)
          addr     = makeAddress(label = "Old", aliases = List("a"))
          _       <- repo.save(addr)
          // update label only -> aliases preserved
          upd1    <- repo.updateLabelAndAliases(addr.id, clientId, Some("New Label"), None)
          // update aliases only -> label preserved
          upd2    <- repo.updateLabelAndAliases(addr.id, clientId, None, Some(List("x", "y")))
          // wrong client -> no row updated
          wrong   <- repo.updateLabelAndAliases(addr.id, otherClientId, Some("Hacked"), None)
        } yield assertTrue(
          upd1.isDefined,
          upd1.get.label == "New Label",
          upd1.get.aliases == List("a"),
          upd2.isDefined,
          upd2.get.label == "New Label",
          upd2.get.aliases == List("x", "y"),
          wrong.isEmpty
        )
      },
      test("findByAddressText matches exact address for client") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanAddresses(xa)
          repo    = PostgresClientAddressRepository(xa)
          addr    = makeAddress(address = "Unique Address 42")
          _      <- repo.save(addr)
          hit    <- repo.findByAddressText(clientId, "Unique Address 42")
          miss   <- repo.findByAddressText(clientId, "Nope")
          wrongC <- repo.findByAddressText(otherClientId, "Unique Address 42")
        } yield assertTrue(
          hit.isDefined,
          hit.get.id == addr.id,
          miss.isEmpty,
          wrongC.isEmpty
        )
      },
      test("delete removes only the matching client's address") {
        for {
          xa      <- ZIO.service[Transactor[Task]]
          _       <- seedTestData(xa)
          _       <- cleanAddresses(xa)
          repo     = PostgresClientAddressRepository(xa)
          addr     = makeAddress()
          _       <- repo.save(addr)
          wrong   <- repo.delete(addr.id, otherClientId)
          ok      <- repo.delete(addr.id, clientId)
          left    <- repo.findByClient(clientId)
        } yield assertTrue(!wrong, ok, left.isEmpty)
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock
}
