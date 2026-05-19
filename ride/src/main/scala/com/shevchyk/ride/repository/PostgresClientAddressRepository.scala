package com.shevchyk.ride.repository

import com.shevchyk.core.domain.PersonId
import com.shevchyk.ride.domain.{ClientAddress, ClientAddressId}
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.Instant
import java.util.UUID

final class PostgresClientAddressRepository(xa: Transactor[Task]) extends ClientAddressRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  private def toClientAddress(
      id: UUID,
      clientId: UUID,
      label: String,
      address: String,
      lat: Option[Double],
      lng: Option[Double],
      useCount: Int,
      aliases: List[String],
      createdAt: Instant,
      updatedAt: Instant
  ): ClientAddress = ClientAddress(
    id = ClientAddressId(id),
    clientId = PersonId(clientId),
    label = label,
    address = address,
    latitude = lat,
    longitude = lng,
    useCount = useCount,
    aliases = aliases,
    createdAt = createdAt,
    updatedAt = updatedAt
  )

  override def findByClient(clientId: PersonId): Task[List[ClientAddress]] =
    sql"""
      SELECT id, client_id, label, address, latitude, longitude, use_count, aliases, created_at, updated_at
      FROM client_addresses
      WHERE client_id = ${clientId.value}
      ORDER BY use_count DESC, updated_at DESC
    """
      .query[(UUID, UUID, String, String, Option[Double], Option[Double], Int, List[String], Instant, Instant)]
      .to[List]
      .transact(xa)
      .map(_.map(toClientAddress.tupled))

  override def save(addr: ClientAddress): Task[ClientAddress] =
    sql"""
      INSERT INTO client_addresses (id, client_id, label, address, latitude, longitude, use_count, aliases, created_at, updated_at)
      VALUES (${addr.id.value}, ${addr.clientId.value}, ${addr.label}, ${addr.address},
              ${addr.latitude}, ${addr.longitude}, ${addr.useCount}, ${addr.aliases},
              ${addr.createdAt}, ${addr.updatedAt})
    """.update.run
      .transact(xa)
      .as(addr)

  override def incrementUseCount(id: ClientAddressId): Task[Unit] =
    sql"""
      UPDATE client_addresses
      SET use_count = use_count + 1, updated_at = NOW()
      WHERE id = ${id.value}
    """.update.run
      .transact(xa)
      .unit

  override def updateLabelAndAliases(
      id: ClientAddressId,
      clientId: PersonId,
      label: Option[String],
      aliases: Option[List[String]]
  ): Task[Option[ClientAddress]] =
    sql"""
      UPDATE client_addresses
      SET label     = COALESCE(${label}, label),
          aliases   = COALESCE(${aliases}, aliases),
          updated_at = NOW()
      WHERE id = ${id.value} AND client_id = ${clientId.value}
      RETURNING id, client_id, label, address, latitude, longitude, use_count, aliases, created_at, updated_at
    """
      .query[(UUID, UUID, String, String, Option[Double], Option[Double], Int, List[String], Instant, Instant)]
      .option
      .transact(xa)
      .map(_.map(toClientAddress.tupled))

  override def delete(id: ClientAddressId, clientId: PersonId): Task[Boolean] =
    sql"""
      DELETE FROM client_addresses
      WHERE id = ${id.value} AND client_id = ${clientId.value}
    """.update.run
      .transact(xa)
      .map(_ > 0)

  override def findByAddressText(clientId: PersonId, address: String): Task[Option[ClientAddress]] =
    sql"""
      SELECT id, client_id, label, address, latitude, longitude, use_count, aliases, created_at, updated_at
      FROM client_addresses
      WHERE client_id = ${clientId.value} AND address = $address
    """
      .query[(UUID, UUID, String, String, Option[Double], Option[Double], Int, List[String], Instant, Instant)]
      .option
      .transact(xa)
      .map(_.map(toClientAddress.tupled))

object PostgresClientAddressRepository:

  val layer: ZLayer[Transactor[Task], Nothing, ClientAddressRepository] = ZLayer.fromFunction(
    PostgresClientAddressRepository(_)
  )
