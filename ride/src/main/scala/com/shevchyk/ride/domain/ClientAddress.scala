package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class ClientAddressId(value: UUID) derives JsonCodec

object ClientAddressId:
  def generate(): ClientAddressId = ClientAddressId(UuidCreator.getTimeOrderedEpoch())

final case class ClientAddress(
    id: ClientAddressId,
    clientId: PersonId,
    label: String,
    address: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None,
    useCount: Int = 1,
    createdAt: Instant = Instant.now(),
    updatedAt: Instant = Instant.now()
) derives JsonCodec

final case class SaveClientAddressRequest(
    label: String,
    address: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None
) derives JsonCodec
