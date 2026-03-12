package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import zio.json.*
import java.time.{Instant, LocalTime}
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class RideTemplateId(value: UUID) derives JsonCodec

object RideTemplateId:
  def generate(): RideTemplateId = RideTemplateId(UuidCreator.getTimeOrderedEpoch())

enum RecurrencePattern derives JsonCodec:
  case DAILY, WEEKLY_MON, WEEKLY_TUE, WEEKLY_WED, WEEKLY_THU, WEEKLY_FRI, WEEKLY_SAT, WEEKLY_SUN, WEEKDAYS, CUSTOM

final case class RideTemplate(
    id: RideTemplateId,
    companyId: CompanyId,
    clientId: PersonId,
    creatorId: PersonId,
    name: String,
    fromAddress: String,
    fromLat: Option[Double] = None,
    fromLng: Option[Double] = None,
    toAddress: String,
    toLat: Option[Double] = None,
    toLng: Option[Double] = None,
    preferredDriverId: Option[PersonId] = None,
    notes: Option[String] = None,
    recurrencePattern: RecurrencePattern,
    recurrenceDays: Option[String] = None,
    pickupTime: LocalTime,
    isActive: Boolean = true,
    flightNumber: Option[String] = None,
    isAirportTransfer: Boolean = false,
    price: Option[BigDecimal] = None,
    createdAt: Instant = Instant.now(),
    updatedAt: Instant = Instant.now()
) derives JsonCodec

final case class CreateRideTemplateRequest(
    clientId: String,
    name: String,
    fromAddress: String,
    fromLat: Option[Double] = None,
    fromLng: Option[Double] = None,
    toAddress: String,
    toLat: Option[Double] = None,
    toLng: Option[Double] = None,
    preferredDriverId: Option[String] = None,
    notes: Option[String] = None,
    recurrencePattern: String,
    recurrenceDays: Option[String] = None,
    pickupTime: String,
    flightNumber: Option[String] = None,
    isAirportTransfer: Boolean = false,
    price: Option[Double] = None
) derives JsonCodec

final case class GenerateRidesRequest(
    fromDate: String,
    toDate: String
) derives JsonCodec
