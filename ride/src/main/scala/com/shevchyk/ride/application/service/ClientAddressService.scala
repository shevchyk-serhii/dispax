package com.shevchyk.ride.application.service

import com.shevchyk.core.domain.PersonId
import com.shevchyk.ride.domain.{ClientAddress, ClientAddressId, SaveClientAddressRequest, UpdateClientAddressRequest}
import com.shevchyk.ride.repository.ClientAddressRepository
import zio.*
import java.time.Instant

trait ClientAddressService:
  def getAddresses(clientId: PersonId): Task[List[ClientAddress]]
  def saveAddress(clientId: PersonId, req: SaveClientAddressRequest): Task[ClientAddress]

  def updateAddress(
      id: ClientAddressId,
      clientId: PersonId,
      req: UpdateClientAddressRequest
  ): Task[Option[ClientAddress]]

  def recordUsage(
      clientId: PersonId,
      address: String,
      label: String,
      lat: Option[Double],
      lng: Option[Double]
  ): Task[Unit]
  def deleteAddress(id: ClientAddressId, clientId: PersonId): Task[Boolean]

class ClientAddressServiceImpl(repo: ClientAddressRepository) extends ClientAddressService:

  override def getAddresses(clientId: PersonId): Task[List[ClientAddress]] = repo.findByClient(clientId)

  override def updateAddress(
      id: ClientAddressId,
      clientId: PersonId,
      req: UpdateClientAddressRequest
  ): Task[Option[ClientAddress]] = repo.updateLabelAndAliases(id, clientId, req.label, req.aliases)

  override def saveAddress(clientId: PersonId, req: SaveClientAddressRequest): Task[ClientAddress] = repo
    .findByAddressText(clientId, req.address)
    .flatMap {
      case Some(existing) => repo.incrementUseCount(existing.id).as(existing)
      case None           =>
        val addr = ClientAddress(
          id = ClientAddressId.generate(),
          clientId = clientId,
          label = req.label,
          address = req.address,
          latitude = req.latitude,
          longitude = req.longitude,
          aliases = req.aliases,
          createdAt = Instant.now(),
          updatedAt = Instant.now()
        )
        repo.save(addr)
    }

  override def recordUsage(
      clientId: PersonId,
      address: String,
      label: String,
      lat: Option[Double],
      lng: Option[Double]
  ): Task[Unit] = repo.findByAddressText(clientId, address).flatMap {
    case Some(existing) => repo.incrementUseCount(existing.id)
    case None           =>
      val addr = ClientAddress(
        id = ClientAddressId.generate(),
        clientId = clientId,
        label = label,
        address = address,
        latitude = lat,
        longitude = lng,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
      )
      repo.save(addr).unit
  }

  override def deleteAddress(id: ClientAddressId, clientId: PersonId): Task[Boolean] = repo.delete(id, clientId)

object ClientAddressService:

  val layer: ZLayer[ClientAddressRepository, Nothing, ClientAddressService] = ZLayer.fromFunction(
    ClientAddressServiceImpl(_)
  )
