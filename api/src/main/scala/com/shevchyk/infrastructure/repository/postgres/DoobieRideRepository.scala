package com.shevchyk.infrastructure.repository.postgres

import com.shevchyk.domain.model.*
import com.shevchyk.domain.repository.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.LocalDateTime

case class DoobieRideRepository(xa: Transactor[Task]) extends RideRepository:

  implicit val rideStatusMeta: Meta[RideStatus] = Meta[String].timap(s => RideStatus.valueOf(s))(_.toString)

  implicit val personIdMeta: Meta[PersonId] = Meta[Int].timap(PersonId.apply)(_.value)

  implicit val rideIdMeta: Meta[RideId] = Meta[Long].timap(RideId.apply)(_.value)

  implicit val companyIdMeta: Meta[CompanyId] = Meta[Int].timap(CompanyId.apply)(_.value)

  def save(ride: Ride): IO[RepositoryError, Ride] =
    val insertSql =
      sql"""
      INSERT INTO rides (
        client_id, creator_id, driver_id, company_id, pickup_datetime,
        from_address, from_lat, from_lng, to_address, to_lat, to_lng,
        status, price_amount, price_currency, estimated_distance_km,
        flight_number, flight_time, flight_gate, flight_terminal, 
        flight_status, flight_is_arrival
      ) VALUES (
        ${ride.clientId}, ${ride.creatorId}, ${ride.driverId}, ${ride.companyId}, 
        ${ride.pickupDateTime}, ${ride.from.address}, ${ride.from.latitude}, 
        ${ride.from.longitude}, ${ride.to.address}, ${ride.to.latitude}, 
        ${ride.to.longitude}, ${ride.status}, ${ride.price.map(_.amount)}, 
        ${ride.price.map(_.currency)}, ${ride.estimatedDistance.map(_.kilometers)},
        ${ride.flightInfo.map(_.flightNumber)}, ${ride.flightInfo.map(_.flightTime)},
        ${ride.flightInfo.flatMap(_.gate)}, ${ride.flightInfo.flatMap(_.terminal)},
        ${ride.flightInfo.map(_.status)}, ${ride.flightInfo.map(_.isArrival)}
      ) RETURNING id
    """

    insertSql
      .query[Long]
      .unique
      .transact(xa)
      .map(id => ride.copy(id = RideId(id)))
      .mapError(RepositoryError.DatabaseError.apply)

  def findById(id: RideId): IO[RepositoryError, Option[Ride]] =
    val selectSql =
      sql"""
      SELECT id, client_id, creator_id, driver_id, company_id, pickup_datetime,
             from_address, from_lat, from_lng, to_address, to_lat, to_lng,
             status, price_amount, price_currency, estimated_distance_km,
             flight_number, flight_time, flight_gate, flight_terminal,
             flight_status, flight_is_arrival
      FROM rides WHERE id = $id
    """

    selectSql
      .query[RideRow]
      .option
      .transact(xa)
      .map(_.map(toRide))
      .mapError(RepositoryError.DatabaseError.apply)

  def findAll(): IO[RepositoryError, List[Ride]] =
    sql"SELECT id, client_id, creator_id, driver_id, company_id, pickup_datetime, from_address, from_lat, from_lng, to_address, to_lat, to_lng, status, price_amount, price_currency, estimated_distance_km, flight_number, flight_time, flight_gate, flight_terminal, flight_status, flight_is_arrival FROM rides ORDER BY created_at DESC"
      .query[RideRow]
      .to[List]
      .transact(xa)
      .map(_.map(toRide))
      .mapError(RepositoryError.DatabaseError.apply)

  def findByClientId(clientId: PersonId): IO[RepositoryError, List[Ride]] =
    sql"SELECT id, client_id, creator_id, driver_id, company_id, pickup_datetime, from_address, from_lat, from_lng, to_address, to_lat, to_lng, status, price_amount, price_currency, estimated_distance_km, flight_number, flight_time, flight_gate, flight_terminal, flight_status, flight_is_arrival FROM rides WHERE client_id = $clientId ORDER BY created_at DESC"
      .query[RideRow]
      .to[List]
      .transact(xa)
      .map(_.map(toRide))
      .mapError(RepositoryError.DatabaseError.apply)

  def findByDriverId(driverId: PersonId): IO[RepositoryError, List[Ride]] =
    sql"SELECT id, client_id, creator_id, driver_id, company_id, pickup_datetime, from_address, from_lat, from_lng, to_address, to_lat, to_lng, status, price_amount, price_currency, estimated_distance_km, flight_number, flight_time, flight_gate, flight_terminal, flight_status, flight_is_arrival FROM rides WHERE driver_id = $driverId ORDER BY created_at DESC"
      .query[RideRow]
      .to[List]
      .transact(xa)
      .map(_.map(toRide))
      .mapError(RepositoryError.DatabaseError.apply)

  def findByCompanyId(companyId: CompanyId): IO[RepositoryError, List[Ride]] =
    sql"SELECT id, client_id, creator_id, driver_id, company_id, pickup_datetime, from_address, from_lat, from_lng, to_address, to_lat, to_lng, status, price_amount, price_currency, estimated_distance_km, flight_number, flight_time, flight_gate, flight_terminal, flight_status, flight_is_arrival FROM rides WHERE company_id = $companyId ORDER BY created_at DESC"
      .query[RideRow]
      .to[List]
      .transact(xa)
      .map(_.map(toRide))
      .mapError(RepositoryError.DatabaseError.apply)

  def findByStatus(status: RideStatus): IO[RepositoryError, List[Ride]] =
    sql"SELECT id, client_id, creator_id, driver_id, company_id, pickup_datetime, from_address, from_lat, from_lng, to_address, to_lat, to_lng, status, price_amount, price_currency, estimated_distance_km, flight_number, flight_time, flight_gate, flight_terminal, flight_status, flight_is_arrival FROM rides WHERE status = $status ORDER BY created_at DESC"
      .query[RideRow]
      .to[List]
      .transact(xa)
      .map(_.map(toRide))
      .mapError(RepositoryError.DatabaseError.apply)

  def update(ride: Ride): IO[RepositoryError, Option[Ride]] =
    val updateSql =
      sql"""
      UPDATE rides SET
        driver_id = ${ride.driverId},
        status = ${ride.status},
        price_amount = ${ride.price.map(_.amount)},
        price_currency = ${ride.price.map(_.currency)},
        estimated_distance_km = ${ride.estimatedDistance.map(_.kilometers)},
        flight_number = ${ride.flightInfo.map(_.flightNumber)},
        flight_time = ${ride.flightInfo.map(_.flightTime)},
        flight_gate = ${ride.flightInfo.flatMap(_.gate)},
        flight_terminal = ${ride.flightInfo.flatMap(_.terminal)},
        flight_status = ${ride.flightInfo.map(_.status)},
        flight_is_arrival = ${ride.flightInfo.map(_.isArrival)},
        updated_at = NOW()
      WHERE id = ${ride.id}
    """

    updateSql.update.run
      .transact(xa)
      .mapError(RepositoryError.DatabaseError.apply)
      .flatMap {
        case 1 => findById(ride.id)
        case 0 => ZIO.succeed(None)
        case n => ZIO.fail(RepositoryError.DatabaseError(new Exception(s"Update affected $n rows, expected 1")))
      }

  def delete(id: RideId): IO[RepositoryError, Boolean] = sql"DELETE FROM rides WHERE id = $id".update.run
    .transact(xa)
    .map(_ > 0)
    .mapError(RepositoryError.DatabaseError.apply)

  private case class RideRow(
      id: RideId,
      clientId: PersonId,
      creatorId: PersonId,
      driverId: Option[PersonId],
      companyId: CompanyId,
      pickupDateTime: LocalDateTime,
      fromAddress: String,
      fromLat: Option[Double],
      fromLng: Option[Double],
      toAddress: String,
      toLat: Option[Double],
      toLng: Option[Double],
      status: RideStatus,
      priceAmount: Option[Double],
      priceCurrency: Option[String],
      estimatedDistanceKm: Option[Double],
      flightNumber: Option[String],
      flightTime: Option[LocalDateTime],
      flightGate: Option[String],
      flightTerminal: Option[String],
      flightStatus: Option[String],
      flightIsArrival: Option[Boolean]
  )

  private def toRide(row: RideRow): Ride = Ride(
    id = row.id,
    clientId = row.clientId,
    creatorId = row.creatorId,
    driverId = row.driverId,
    companyId = row.companyId,
    pickupDateTime = row.pickupDateTime,
    from = Location(row.fromAddress, row.fromLat, row.fromLng),
    to = Location(row.toAddress, row.toLat, row.toLng),
    status = row.status,
    price =
      (row.priceAmount, row.priceCurrency) match {
        case (Some(amount), Some(currency)) => Some(Price(amount, currency))
        case _                              => None
      },
    estimatedDistance = row.estimatedDistanceKm.map(Distance.apply),
    flightInfo = row.flightNumber.map { fn =>
      FlightInfo(
        flightNumber = fn,
        flightTime = row.flightTime.getOrElse(row.pickupDateTime),
        gate = row.flightGate,
        terminal = row.flightTerminal,
        status = row.flightStatus.getOrElse("On Time"),
        isArrival = row.flightIsArrival.getOrElse(true)
      )
    }
  )
