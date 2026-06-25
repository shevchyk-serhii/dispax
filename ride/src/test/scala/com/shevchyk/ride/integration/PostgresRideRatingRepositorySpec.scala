package com.shevchyk.ride.integration

import com.shevchyk.core.database.PostgresTestContainer
import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.PostgresRideRatingRepository
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
 * Integration tests for PostgresRideRatingRepository against a real PostgreSQL database via Testcontainers.
 */
object PostgresRideRatingRepositorySpec extends ZIOSpecDefault {

  val testCompanyId = CompanyId(UUID.fromString("00000020-0000-0000-0000-000000000001"))
  val clientId      = PersonId(UUID.fromString("00000021-0000-0000-0000-000000000001"))
  val driverId      = PersonId(UUID.fromString("00000021-0000-0000-0000-000000000002"))
  val otherDriverId = PersonId(UUID.fromString("00000021-0000-0000-0000-000000000003"))
  val rideId1       = RideId(UUID.fromString("00000022-0000-0000-0000-000000000001"))
  val rideId2       = RideId(UUID.fromString("00000022-0000-0000-0000-000000000002"))
  val rideId3       = RideId(UUID.fromString("00000022-0000-0000-0000-000000000003"))

  private def seedRide(xa: Transactor[Task], rid: RideId): Task[Unit] =
    sql"""INSERT INTO rides (id, client_id, creator_id, company_id, status,
            from_address, to_address, pickup_datetime, request_time)
            VALUES (${rid.value}, ${clientId.value}, ${clientId.value}, ${testCompanyId.value}, 'Completed',
            'A', 'B', NOW(), NOW())
            ON CONFLICT DO NOTHING""".update.run.transact(xa).unit

  private def seedTestData(xa: Transactor[Task]): Task[Unit] =
    (for {
      _ <-
        sql"""INSERT INTO companies (id, name, email) VALUES (${testCompanyId.value}, 'Rating GmbH', 'rating-test@example.com')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${clientId.value}, 'Rating Client', 'rating-client@test.com', 'client'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${driverId.value}, 'Rating Driver', 'rating-driver@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
      _ <-
        sql"""INSERT INTO persons (id, name, email, role, company_id, password_hash)
                 VALUES (${otherDriverId.value}, 'Rating Driver 2', 'rating-driver2@test.com', 'driver'::person_role, ${testCompanyId.value}, 'placeholder')
                 ON CONFLICT DO NOTHING""".update.run
    } yield ()).transact(xa) *> seedRide(xa, rideId1) *> seedRide(xa, rideId2) *> seedRide(xa, rideId3)

  private def cleanRatings(xa: Transactor[Task]): Task[Unit] =
    sql"DELETE FROM ride_ratings".update.run.transact(xa).unit

  private def makeRating(
      ride: RideId,
      driver: PersonId = driverId,
      rating: Int,
      comment: Option[String] = Some("great"),
      createdAt: Instant = Instant.now().truncatedTo(ChronoUnit.MICROS)
  ): RideRating = RideRating(
    id = RideRatingId.generate(),
    rideId = ride,
    clientId = clientId,
    driverId = driver,
    companyId = testCompanyId,
    rating = rating,
    comment = comment,
    createdAt = createdAt
  )

  def spec =
    suite("PostgresRideRatingRepository")(
      test("create and findByRideId round-trip") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRatings(xa)
          repo   = PostgresRideRatingRepository(xa)
          r      = makeRating(rideId1, rating = 4, comment = Some("solid"))
          _     <- repo.create(r)
          found <- repo.findByRideId(rideId1)
          none  <- repo.findByRideId(rideId2)
        } yield assertTrue(
          found.isDefined,
          found.get.id == r.id,
          found.get.rideId == rideId1,
          found.get.driverId == driverId,
          found.get.companyId == testCompanyId,
          found.get.rating == 4,
          found.get.comment.contains("solid"),
          none.isEmpty
        )
      },
      test("findByDriverId returns all ratings for driver") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRatings(xa)
          repo   = PostgresRideRatingRepository(xa)
          _     <- repo.create(makeRating(rideId1, driver = driverId, rating = 5))
          _     <- repo.create(makeRating(rideId2, driver = driverId, rating = 3))
          _     <- repo.create(makeRating(rideId3, driver = otherDriverId, rating = 1))
          mine  <- repo.findByDriverId(driverId)
          other <- repo.findByDriverId(otherDriverId)
        } yield assertTrue(
          mine.length == 2,
          mine.forall(_.driverId == driverId),
          other.length == 1,
          other.head.rating == 1
        )
      },
      test("getDriverAvgRating averages ratings") {
        for {
          xa     <- ZIO.service[Transactor[Task]]
          _      <- seedTestData(xa)
          _      <- cleanRatings(xa)
          repo    = PostgresRideRatingRepository(xa)
          _      <- repo.create(makeRating(rideId1, driver = driverId, rating = 5))
          _      <- repo.create(makeRating(rideId2, driver = driverId, rating = 3))
          avg    <- repo.getDriverAvgRating(driverId)
          noData <- repo.getDriverAvgRating(otherDriverId)
        } yield assertTrue(
          avg.isDefined,
          math.abs(avg.get - 4.0) < 1e-9,
          noData.isEmpty
        )
      },
      test("driverRatingStatsByCompany aggregates avg and count per driver in one query") {
        for {
          xa    <- ZIO.service[Transactor[Task]]
          _     <- seedTestData(xa)
          _     <- cleanRatings(xa)
          repo   = PostgresRideRatingRepository(xa)
          _     <- repo.create(makeRating(rideId1, driver = driverId, rating = 5))
          _     <- repo.create(makeRating(rideId2, driver = driverId, rating = 3))
          _     <- repo.create(makeRating(rideId3, driver = otherDriverId, rating = 2))
          stats <- repo.driverRatingStatsByCompany(testCompanyId)
          empty <- repo.driverRatingStatsByCompany(CompanyId(UUID.randomUUID()))
        } yield assertTrue(
          stats.size == 2,
          math.abs(stats(driverId)._1 - 4.0) < 1e-9,
          stats(driverId)._2 == 2,
          math.abs(stats(otherDriverId)._1 - 2.0) < 1e-9,
          stats(otherDriverId)._2 == 1,
          empty.isEmpty
        )
      }
    ).provide(PostgresTestContainer.layer) @@ TestAspect.sequential @@ TestAspect.withLiveClock @@ TestAspect.tag(
      "integration"
    )
}
