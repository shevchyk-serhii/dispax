package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.*
import java.util.concurrent.ConcurrentHashMap
import scala.jdk.CollectionConverters.*

trait RideRatingRepository:
  def create(rating: RideRating): Task[RideRating]
  def findByRideId(rideId: RideId): Task[Option[RideRating]]
  def findByDriverId(driverId: PersonId): Task[List[RideRating]]
  def getDriverAvgRating(driverId: PersonId): Task[Option[Double]]

class InMemoryRideRatingRepository extends RideRatingRepository:
  private val store = new ConcurrentHashMap[RideRatingId, RideRating]()

  def create(rating: RideRating): Task[RideRating] = ZIO.succeed {
    store.put(rating.id, rating)
    rating
  }

  def findByRideId(rideId: RideId): Task[Option[RideRating]] = ZIO.succeed {
    store.values().asScala.find(_.rideId == rideId)
  }

  def findByDriverId(driverId: PersonId): Task[List[RideRating]] = ZIO.succeed {
    store
      .values()
      .asScala
      .filter(_.driverId == driverId)
      .toList
      .sortBy(_.createdAt)(using Ordering[java.time.Instant].reverse)
  }

  def getDriverAvgRating(driverId: PersonId): Task[Option[Double]] = ZIO.succeed {
    val ratings = store.values().asScala.filter(_.driverId == driverId).map(_.rating).toList
    if ratings.isEmpty then None
    else Some(ratings.sum.toDouble / ratings.size)
  }

object RideRatingRepository:
  val inMemory: ZLayer[Any, Nothing, RideRatingRepository] = ZLayer.succeed(new InMemoryRideRatingRepository)

  val layer: ZLayer[Any, Throwable, RideRatingRepository] =
    com.shevchyk.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresRideRatingRepository.postgresLayer
