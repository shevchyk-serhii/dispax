package com.shevchyk.ride.repository

import com.shevchyk.ride.domain.{Ride, RideStatus}
import com.shevchyk.core.domain.{Location, RideId, PersonId, CompanyId}
import zio.*
import java.time.Instant

trait RideRepository {
  def create(ride: Ride): Task[Ride]
  def findById(id: RideId): Task[Option[Ride]]
  def findByStatus(status: RideStatus): Task[List[Ride]]
  def findAll(): Task[List[Ride]]
  def findByClientId(clientId: PersonId): Task[List[Ride]]
  def findByDriverId(driverId: PersonId): Task[List[Ride]]
  def findByCompanyId(companyId: CompanyId): Task[List[Ride]]
  def update(ride: Ride): Task[Ride]
  def delete(id: RideId): Task[Unit]
  def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]]
  def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal]
  def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal]
  def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double]
  def countDailyStatsByCompany(companyId: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]]
}

object RideRepository {
  import com.shevchyk.core.database.DatabaseConfig
  import doobie.Transactor

  val postgresLayer: ZLayer[Transactor[Task], Nothing, RideRepository] = ZLayer.fromFunction(
    PostgresRideRepository.apply
  )

  val layer: ZLayer[Any, Throwable, RideRepository] = DatabaseConfig.liveTransactorWithMigrations >>> postgresLayer
}
