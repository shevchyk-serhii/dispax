package com.shevchyk.ride.repository

import com.shevchyk.core.domain.PersonId
import com.shevchyk.ride.domain.{ClientAddress, ClientAddressId}
import com.shevchyk.core.database.DatabaseConfig
import zio.*

trait ClientAddressRepository:
  def findByClient(clientId: PersonId): Task[List[ClientAddress]]
  def save(address: ClientAddress): Task[ClientAddress]
  def incrementUseCount(id: ClientAddressId): Task[Unit]

  def updateLabelAndAliases(
      id: ClientAddressId,
      clientId: PersonId,
      label: Option[String],
      aliases: Option[List[String]]
  ): Task[Option[ClientAddress]]
  def delete(id: ClientAddressId, clientId: PersonId): Task[Boolean]
  def findByAddressText(clientId: PersonId, address: String): Task[Option[ClientAddress]]

object ClientAddressRepository:

  val layer: ZLayer[Any, Throwable, ClientAddressRepository] =
    DatabaseConfig.liveTransactorWithMigrations >>> PostgresClientAddressRepository.layer
