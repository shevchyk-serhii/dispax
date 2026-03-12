package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.*
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

trait ExpenseRepository:
  def create(expense: Expense): Task[Expense]
  def findById(id: ExpenseId): Task[Option[Expense]]
  def findByDriverId(driverId: PersonId): Task[List[Expense]]
  def findByRideId(rideId: RideId): Task[List[Expense]]
  def findByCompanyId(companyId: CompanyId): Task[List[Expense]]
  def delete(id: ExpenseId): Task[Boolean]

class InMemoryExpenseRepository extends ExpenseRepository:
  private val store = new ConcurrentHashMap[ExpenseId, Expense]()

  def create(expense: Expense): Task[Expense] = ZIO.succeed {
    store.put(expense.id, expense)
    expense
  }

  def findById(id: ExpenseId): Task[Option[Expense]] = ZIO.succeed {
    Option(store.get(id))
  }

  def findByDriverId(driverId: PersonId): Task[List[Expense]] = ZIO.succeed {
    store.values().asScala.filter(_.driverId == driverId).toList.sortBy(_.createdAt)
  }

  def findByRideId(rideId: RideId): Task[List[Expense]] = ZIO.succeed {
    store.values().asScala.filter(_.rideId.contains(rideId)).toList.sortBy(_.createdAt)
  }

  def findByCompanyId(companyId: CompanyId): Task[List[Expense]] = ZIO.succeed {
    store.values().asScala.filter(_.companyId == companyId).toList.sortBy(_.createdAt)
  }

  def delete(id: ExpenseId): Task[Boolean] = ZIO.succeed {
    store.remove(id) != null
  }

object ExpenseRepository:
  val inMemory: ZLayer[Any, Nothing, ExpenseRepository] = ZLayer.succeed(new InMemoryExpenseRepository)

  val layer: ZLayer[Any, Throwable, ExpenseRepository] =
    com.shevchyk.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresExpenseRepository.postgresLayer
