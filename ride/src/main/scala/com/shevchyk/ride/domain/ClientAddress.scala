package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class ClientAddressId(value: UUID)

object ClientAddressId:
  def generate(): ClientAddressId  = ClientAddressId(UuidCreator.getTimeOrderedEpoch())
  given JsonCodec[ClientAddressId] = JsonCodec[UUID].transform(ClientAddressId(_), _.value)

final case class ClientAddress(
    id: ClientAddressId,
    clientId: PersonId,
    label: String,
    address: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None,
    useCount: Int = 1,
    aliases: List[String] = Nil,
    createdAt: Instant = Instant.now(),
    updatedAt: Instant = Instant.now()
) derives JsonCodec

final case class SaveClientAddressRequest(
    label: String,
    address: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None,
    aliases: List[String] = Nil
) derives JsonCodec

final case class UpdateClientAddressRequest(
    label: Option[String] = None,
    aliases: Option[List[String]] = None
) derives JsonCodec
