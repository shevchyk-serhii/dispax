package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresRideRatingRepository(xa: Transactor[Task]) extends RideRatingRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def create(rating: RideRating): Task[RideRating] =
    sql"""
      INSERT INTO ride_ratings (id, ride_id, client_id, driver_id, company_id, rating, comment, created_at)
      VALUES (${rating.id.value}, ${rating.rideId.value}, ${rating.clientId.value},
              ${rating.driverId.value}, ${rating.companyId.value}, ${rating.rating},
              ${rating.comment}, ${rating.createdAt})
    """.update.run
      .transact(xa)
      .as(rating)

  override def findByRideId(rideId: RideId): Task[Option[RideRating]] =
    sql"""
      SELECT id, ride_id, client_id, driver_id, company_id, rating, comment, created_at
      FROM ride_ratings WHERE ride_id = ${rideId.value}
    """
      .query[RideRating]
      .option
      .transact(xa)

  override def findByDriverId(driverId: PersonId): Task[List[RideRating]] =
    sql"""
      SELECT id, ride_id, client_id, driver_id, company_id, rating, comment, created_at
      FROM ride_ratings WHERE driver_id = ${driverId.value} ORDER BY created_at DESC
    """
      .query[RideRating]
      .to[List]
      .transact(xa)

  override def getDriverAvgRating(driverId: PersonId): Task[Option[Double]] =
    sql"""
      SELECT AVG(rating)::double precision FROM ride_ratings WHERE driver_id = ${driverId.value}
    """
      .query[Option[Double]]
      .unique
      .transact(xa)

  implicit val ratingRead: Read[RideRating] = Read[(UUID, UUID, UUID, UUID, UUID, Int, Option[String], Instant)].map {
    case (id, rideId, clientId, driverId, companyId, rating, comment, createdAt) =>
      RideRating(
        id = RideRatingId(id),
        rideId = RideId(rideId),
        clientId = PersonId(clientId),
        driverId = PersonId(driverId),
        companyId = CompanyId(companyId),
        rating = rating,
        comment = comment,
        createdAt = createdAt
      )
  }

object PostgresRideRatingRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, RideRatingRepository] = ZLayer.fromFunction(
    PostgresRideRatingRepository(_)
  )
