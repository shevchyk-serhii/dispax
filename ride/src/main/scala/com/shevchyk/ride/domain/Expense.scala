package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import zio.json.*
import java.time.Instant
import java.util.UUID

case class ExpenseId(value: UUID)

object ExpenseId:
  def generate(): ExpenseId  = ExpenseId(com.github.f4b6a3.uuid.UuidCreator.getTimeOrderedEpoch())
  given JsonCodec[ExpenseId] = JsonCodec[UUID].transform(ExpenseId(_), _.value)

enum ExpenseCategory derives JsonCodec:
  case Fuel, Parking, Tolls, Cleaning, Maintenance, Other

final case class Expense(
    id: ExpenseId,
    rideId: Option[RideId] = None,
    driverId: PersonId,
    companyId: CompanyId,
    category: ExpenseCategory,
    amount: BigDecimal,
    currency: String = "EUR",
    description: Option[String] = None,
    receiptUrl: Option[String] = None,
    createdAt: Instant = Instant.now(),
    updatedAt: Instant = Instant.now()
) derives JsonCodec

final case class CreateExpenseRequest(
    rideId: Option[String] = None,
    category: String,
    amount: Double,
    description: Option[String] = None
) derives JsonCodec
