package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class BlacklistEntryId(value: UUID) derives JsonCodec

object BlacklistEntryId:
  def generate(): BlacklistEntryId = BlacklistEntryId(UuidCreator.getTimeOrderedEpoch())

case class BlacklistEntry(
    id: BlacklistEntryId,
    companyId: CompanyId,
    clientId: PersonId,
    driverId: PersonId,
    reason: Option[String] = None,
    createdBy: PersonId,
    createdAt: Instant = Instant.now(),
    isActive: Boolean = true
) derives JsonCodec

case class CreateBlacklistRequest(
    clientId: String,
    driverId: String,
    reason: Option[String] = None
) derives JsonCodec
