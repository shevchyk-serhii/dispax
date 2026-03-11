package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{RideId, PersonId}
import com.shevchyk.ride.domain.ClientLocation
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.Instant
import java.util.UUID

final class PostgresClientLocationRepository(xa: Transactor[Task]) extends ClientLocationRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def updateLocation(rideId: RideId, clientId: PersonId, latitude: Double, longitude: Double): Task[Unit] =
    sql"""
      INSERT INTO client_locations (ride_id, client_id, latitude, longitude, updated_at)
      VALUES (${rideId.value}, ${clientId.value}, $latitude, $longitude, NOW())
      ON CONFLICT (ride_id) DO UPDATE SET
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        updated_at = NOW()
    """.update.run
      .transact(xa)
      .unit

  override def getLocation(rideId: RideId): Task[Option[ClientLocation]] =
    sql"""
      SELECT ride_id, client_id, latitude, longitude, updated_at
      FROM client_locations
      WHERE ride_id = ${rideId.value}
    """
      .query[(UUID, UUID, Double, Double, Instant)]
      .option
      .transact(xa)
      .map(_.map { case (rideId, clientId, lat, lng, updatedAt) =>
        ClientLocation(RideId(rideId), PersonId(clientId), lat, lng, updatedAt)
      })

object PostgresClientLocationRepository:

  val layer: ZLayer[Transactor[Task], Nothing, ClientLocationRepository] = ZLayer.fromFunction(
    PostgresClientLocationRepository(_)
  )
