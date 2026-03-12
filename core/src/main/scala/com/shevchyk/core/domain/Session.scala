package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class SessionId(value: UUID) derives JsonCodec

object SessionId:
  def generate(): SessionId = SessionId(UuidCreator.getTimeOrderedEpoch())

case class Session(
    id: SessionId,
    userId: PersonId,
    token: String,
    deviceInfo: Option[String] = None,
    ipAddress: Option[String] = None,
    createdAt: Instant,
    lastActiveAt: Instant,
    isActive: Boolean = true
) derives JsonCodec

case class SessionDto(
    id: UUID,
    deviceInfo: Option[String],
    ipAddress: Option[String],
    createdAt: String,
    lastActiveAt: String,
    isActive: Boolean,
    isCurrent: Boolean = false
) derives JsonCodec
