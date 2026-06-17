package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresExpenseRepository(xa: Transactor[Task]) extends ExpenseRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  implicit val expenseCategoryMeta: Meta[ExpenseCategory] = Meta[String].imap(ExpenseCategory.valueOf)(_.toString)

  override def create(expense: Expense): Task[Expense] =
    sql"""
      INSERT INTO expenses (id, ride_id, driver_id, company_id, category, amount, currency, description, receipt_url, created_at, updated_at)
      VALUES (${expense.id.value}, ${expense.rideId.map(_.value)}, ${expense.driverId.value},
              ${expense.companyId.value}, ${expense.category.toString}, ${expense.amount},
              ${expense.currency}, ${expense.description}, ${expense.receiptUrl},
              ${expense.createdAt}, ${expense.updatedAt})
    """.update.run
      .transact(xa)
      .as(expense)

  override def findById(id: ExpenseId): Task[Option[Expense]] =
    sql"""
      SELECT id, ride_id, driver_id, company_id, category, amount, currency, description, receipt_url, created_at, updated_at
      FROM expenses WHERE id = ${id.value}
    """
      .query[Expense]
      .option
      .transact(xa)

  override def findByDriverId(driverId: PersonId): Task[List[Expense]] =
    sql"""
      SELECT id, ride_id, driver_id, company_id, category, amount, currency, description, receipt_url, created_at, updated_at
      FROM expenses WHERE driver_id = ${driverId.value} ORDER BY created_at
    """
      .query[Expense]
      .to[List]
      .transact(xa)

  override def findByRideId(rideId: RideId): Task[List[Expense]] =
    sql"""
      SELECT id, ride_id, driver_id, company_id, category, amount, currency, description, receipt_url, created_at, updated_at
      FROM expenses WHERE ride_id = ${rideId.value} ORDER BY created_at
    """
      .query[Expense]
      .to[List]
      .transact(xa)

  override def findByCompanyId(companyId: CompanyId): Task[List[Expense]] =
    sql"""
      SELECT id, ride_id, driver_id, company_id, category, amount, currency, description, receipt_url, created_at, updated_at
      FROM expenses WHERE company_id = ${companyId.value} ORDER BY created_at
    """
      .query[Expense]
      .to[List]
      .transact(xa)

  override def delete(id: ExpenseId, companyId: CompanyId): Task[Boolean] =
    sql"""DELETE FROM expenses WHERE id = ${id.value} AND company_id = ${companyId.value}""".update.run
      .transact(xa)
      .map(_ > 0)

  override def sumByDriver(driverId: PersonId, companyId: CompanyId, from: Instant, to: Instant): Task[BigDecimal] =
    sql"""
      SELECT COALESCE(SUM(amount), 0)
      FROM expenses
      WHERE driver_id = ${driverId.value}
        AND company_id = ${companyId.value}
        AND created_at >= $from
        AND created_at < $to
    """
      .query[BigDecimal]
      .unique
      .transact(xa)

  implicit val expenseRead: Read[Expense] =
    Read[(UUID, Option[UUID], UUID, UUID, String, BigDecimal, String, Option[String], Option[String], Instant, Instant)]
      .map {
        case (
              id,
              rideId,
              driverId,
              companyId,
              category,
              amount,
              currency,
              description,
              receiptUrl,
              createdAt,
              updatedAt
            ) =>
          Expense(
            id = ExpenseId(id),
            rideId = rideId.map(RideId.apply),
            driverId = PersonId(driverId),
            companyId = CompanyId(companyId),
            category = ExpenseCategory.valueOf(category),
            amount = amount,
            currency = currency,
            description = description,
            receiptUrl = receiptUrl,
            createdAt = createdAt,
            updatedAt = updatedAt
          )
      }

object PostgresExpenseRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, ExpenseRepository] = ZLayer.fromFunction(
    PostgresExpenseRepository(_)
  )
