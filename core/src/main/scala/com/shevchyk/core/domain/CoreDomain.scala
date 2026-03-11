package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class PersonId(value: UUID) derives JsonCodec
case class CompanyId(value: UUID) derives JsonCodec
case class RideId(value: UUID) derives JsonCodec
case class TariffId(value: UUID) derives JsonCodec
case class ScheduleDayId(value: UUID) derives JsonCodec

object PersonId:
  def generate(): PersonId = PersonId(UuidCreator.getTimeOrderedEpoch())

object CompanyId:
  def generate(): CompanyId = CompanyId(UuidCreator.getTimeOrderedEpoch())

object RideId:
  def generate(): RideId = RideId(UuidCreator.getTimeOrderedEpoch())

object TariffId:
  def generate(): TariffId = TariffId(UuidCreator.getTimeOrderedEpoch())

object ScheduleDayId:
  def generate(): ScheduleDayId = ScheduleDayId(UuidCreator.getTimeOrderedEpoch())

final case class Location(
    address: String,
    latitude: Option[Double] = None,
    longitude: Option[Double] = None
) derives JsonCodec:
  def display: String = address

object Location:
  def apply(address: String): Location = Location(address, None, None)

enum PersonRole derives JsonCodec:
  case Driver, Client, Secretary, Dispatcher

final case class Person(
    id: PersonId,
    name: String,
    email: String,
    role: PersonRole,
    companyId: Option[CompanyId] = None,
    licenseNumber: Option[String] = None,
    phone: Option[String] = None
) derives JsonCodec

final case class Company(
    id: CompanyId,
    name: String,
    email: String,
    phone: String,
    address: String
) derives JsonCodec
