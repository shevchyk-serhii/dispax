package com.shevchyk.ride.repository.helpers

import com.shevchyk.core.domain.PersonId
import com.shevchyk.ride.domain.{ClientAddress, ClientAddressId}
import com.shevchyk.ride.repository.ClientAddressRepository
import zio.*
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

class InMemoryClientAddressRepository extends ClientAddressRepository:
  private val store = new ConcurrentHashMap[ClientAddressId, ClientAddress]()

  def findByClient(clientId: PersonId): Task[List[ClientAddress]] =
    ZIO.succeed(store.values.asScala.filter(_.clientId == clientId).toList)

  def save(address: ClientAddress): Task[ClientAddress] =
    ZIO.succeed { store.put(address.id, address); address }

  def incrementUseCount(id: ClientAddressId): Task[Unit] =
    ZIO.succeed {
      Option(store.get(id)).foreach(a => store.put(id, a.copy(useCount = a.useCount + 1)))
    }

  def delete(id: ClientAddressId, clientId: PersonId): Task[Boolean] =
    ZIO.succeed {
      Option(store.get(id)) match
        case Some(a) if a.clientId == clientId => store.remove(id); true
        case _                                 => false
    }

  def findByAddressText(clientId: PersonId, address: String): Task[Option[ClientAddress]] =
    ZIO.succeed(store.values.asScala.find(a => a.clientId == clientId && a.address == address))

object InMemoryClientAddressRepository:
  val layer: ULayer[ClientAddressRepository] = ZLayer.succeed(InMemoryClientAddressRepository())
