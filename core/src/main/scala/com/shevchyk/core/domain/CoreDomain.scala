package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant

case class PersonId(value: Long) derives JsonCodec
case class CompanyId(value: Long) derives JsonCodec
case class RideId(value: Long) derives JsonCodec
case class TariffId(value: Long) derives JsonCodec

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
