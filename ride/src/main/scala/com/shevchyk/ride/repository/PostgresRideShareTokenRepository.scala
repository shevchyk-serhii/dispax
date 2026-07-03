package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{CompanyId, RideId, RideShareTokenId}
import com.shevchyk.ride.domain.RideShareToken
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.Instant
import java.util.UUID

final class PostgresRideShareTokenRepository(xa: Transactor[Task]) extends RideShareTokenRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  private val selectColumns = fr"SELECT id, token, ride_id, company_id, created_at, expires_at FROM ride_share_tokens"

  private def toDomain(row: (UUID, String, UUID, UUID, Instant, Instant)): RideShareToken =
    val (id, token, rideId, companyId, createdAt, expiresAt) = row
    RideShareToken(RideShareTokenId(id), token, RideId(rideId), CompanyId(companyId), createdAt, expiresAt)

  override def create(token: RideShareToken): Task[RideShareToken] =
    sql"""
      INSERT INTO ride_share_tokens (id, token, ride_id, company_id, created_at, expires_at)
      VALUES (${token.id.value}, ${token.token}, ${token.rideId.value}, ${token.companyId.value},
              ${token.createdAt}, ${token.expiresAt})
    """.update.run
      .transact(xa)
      .as(token)

  override def findByToken(token: String): Task[Option[RideShareToken]] = (selectColumns ++ fr"WHERE token = $token")
    .query[(UUID, String, UUID, UUID, Instant, Instant)]
    .option
    .transact(xa)
    .map(_.map(toDomain))

  override def findActiveByRideId(rideId: RideId): Task[Option[RideShareToken]] =
    (selectColumns ++ fr"WHERE ride_id = ${rideId.value} AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1")
      .query[(UUID, String, UUID, UUID, Instant, Instant)]
      .option
      .transact(xa)
      .map(_.map(toDomain))

  override def deleteByRideId(rideId: RideId): Task[Int] =
    sql"DELETE FROM ride_share_tokens WHERE ride_id = ${rideId.value}".update.run.transact(xa)

object PostgresRideShareTokenRepository:

  val layer: ZLayer[Transactor[Task], Nothing, RideShareTokenRepository] = ZLayer.fromFunction(
    PostgresRideShareTokenRepository(_)
  )
