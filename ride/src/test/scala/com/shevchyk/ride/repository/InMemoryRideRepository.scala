package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{RideId, PersonId, CompanyId}
import com.shevchyk.ride.domain.{Ride, RideStatus}
import zio.*
import java.time.Instant

class InMemoryRideRepository extends RideRepository:
  private val rides = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[RideId, Ride])).getOrThrowFiberFailure()
  }
  override def create(ride: Ride): Task[Ride] =
    val rideWithId = ride.copy(id = RideId.generate())
    rides.update(_.updated(rideWithId.id, rideWithId)).as(rideWithId)

  override def findById(id: RideId): Task[Option[Ride]] =
    rides.get.map(_.get(id))

  override def update(ride: Ride): Task[Ride] =
    rides.update(_.updated(ride.id, ride)).as(ride)

  override def findByClientId(clientId: PersonId): Task[List[Ride]] =
    rides.get.map(_.values.filter(_.clientId == clientId).toList)

  override def findByDriverId(driverId: PersonId): Task[List[Ride]] =
    rides.get.map(_.values.filter(_.driverId.contains(driverId)).toList)

  override def findByStatus(status: RideStatus): Task[List[Ride]] =
    rides.get.map(_.values.filter(_.status == status).toList)

  override def findByCompanyId(companyId: CompanyId): Task[List[Ride]] =
    rides.get.map(_.values.filter(_.companyId == companyId).toList)

  override def findAll(): Task[List[Ride]] =
    rides.get.map(_.values.toList)

  override def delete(id: RideId): Task[Unit] =
    rides.update(_.removed(id)).unit

  override def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]] =
    rides.get.map(_.values.filter(_.companyId == companyId).groupBy(_.status.toString).map((k, v) => k -> v.size))

  override def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal] =
    rides.get.map(
      _.values
        .filter(r => r.companyId == companyId && r.status == RideStatus.Completed)
        .flatMap(r => r.finalPrice.orElse(r.estimatedPrice))
        .sum
    )

  override def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal] =
    val todayStart = java.time.LocalDate.now().atStartOfDay(java.time.ZoneOffset.UTC).toInstant
    rides.get.map(
      _.values
        .filter(r =>
          r.companyId == companyId &&
            r.status == RideStatus.Completed &&
            r.endTime.exists(!_.isBefore(todayStart))
        )
        .flatMap(r => r.finalPrice.orElse(r.estimatedPrice))
        .sum
    )

  override def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double] =
    rides.get.map { all =>
      val assigned = all.values.filter(r =>
        r.companyId == companyId &&
          r.driverId.isDefined &&
          r.startTime.isDefined
      )
      if assigned.isEmpty then 0.0
      else
        val totalMinutes = assigned.map { r =>
          java.time.Duration.between(r.requestTime, r.startTime.get).toMinutes.toDouble
        }.sum
        totalMinutes / assigned.size
    }

  override def countDailyStatsByCompany(companyId: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]] =
    val cutoff = Instant.now().minusSeconds(days.toLong * 86400)
    rides.get.map { all =>
      val relevant = all.values.filter(r => r.companyId == companyId && r.requestTime.isAfter(cutoff))
      relevant
        .groupBy(r => r.requestTime.atZone(java.time.ZoneOffset.UTC).toLocalDate.toString)
        .map { case (date, rides) =>
          val total     = rides.size
          val completed = rides.count(_.status == RideStatus.Completed)
          val cancelled = rides.count(_.status == RideStatus.Cancelled)
          (date, total, completed, cancelled)
        }
        .toList
        .sortBy(_._1)
    }

object InMemoryRideRepository:
  val layer: ZLayer[Any, Nothing, RideRepository] =
    ZLayer.succeed(new InMemoryRideRepository)