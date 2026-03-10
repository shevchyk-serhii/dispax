package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.{Ride, RideError, RideSpecifics, RideStatus}
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import doobie.postgres.circe.jsonb.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.Instant
import java.util.UUID

final class PostgresRideRepository(xa: Transactor[Task]) extends RideRepository {

  // Import Circe codecs from domain
  import io.circe.{Encoder, Decoder}
  import RideSpecifics.{given Encoder[RideSpecifics], given Decoder[RideSpecifics]}

  // Meta instance for JSONB RideSpecifics
  implicit val rideSpecificsMeta: Meta[Option[RideSpecifics]] =
    Meta.Advanced
      .other[io.circe.Json]("jsonb")
      .imap { json =>
        json.as[Option[RideSpecifics]] match {
          case Right(value) => value
          case Left(err)    => None
        }
      } { maybeSpec =>
        import io.circe.syntax.*
        maybeSpec.asJson
      }

  implicit val rideStatusMeta: Meta[RideStatus] = pgEnumString(
    "ride_status",
    {
      case "Requested"  => RideStatus.Requested
      case "Assigned"   => RideStatus.Assigned
      case "InProgress" => RideStatus.InProgress
      case "Completed"  => RideStatus.Completed
      case "Cancelled"  => RideStatus.Cancelled
    },
    {
      case RideStatus.Requested  => "Requested"
      case RideStatus.Assigned   => "Assigned"
      case RideStatus.InProgress => "InProgress"
      case RideStatus.Completed  => "Completed"
      case RideStatus.Cancelled  => "Cancelled"
    }
  )

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def create(ride: Ride): Task[Ride] = {
    sql"""
      INSERT INTO rides (
        id, client_id, creator_id, company_id, driver_id,
        pickup_datetime, scheduled_time, request_time, start_time, end_time,
        from_address, from_lat, from_lng,
        to_address, to_lat, to_lng,
        status,
        estimated_price_amount, estimated_price_currency,
        final_price_amount, final_price_currency,
        notes, specifics
      ) VALUES (
        ${ride.id.value}, ${ride.clientId.value}, ${ride.creatorId.value}, ${ride.companyId.value}, ${ride.driverId.map(
        _.value
      )},
        ${ride.requestTime}, ${ride.scheduledTime}, ${ride.requestTime}, ${ride.startTime}, ${ride.endTime},
        ${ride.pickupLocation.address}, ${ride.pickupLocation.latitude}, ${ride.pickupLocation.longitude},
        ${ride.dropoffLocation.address}, ${ride.dropoffLocation.latitude}, ${ride.dropoffLocation.longitude},
        ${ride.status},
        ${ride.estimatedPrice}, ${"EUR"},
        ${ride.finalPrice}, ${"EUR"},
        ${ride.notes}, ${ride.specifics}
      )
    """.update.run
      .transact(xa)
      .mapBoth(ex => RideError.DatabaseError(ex), _ => ride)
  }

  override def findById(id: RideId): Task[Option[Ride]] = {
    sql"""
      SELECT
        id, client_id, creator_id, company_id, driver_id,
        pickup_datetime, scheduled_time, request_time, start_time, end_time,
        from_address, from_lat, from_lng,
        to_address, to_lat, to_lng,
        status, tariff_id,
        estimated_price_amount, final_price_amount,
        notes, specifics
      FROM rides
      WHERE id = ${id.value}
    """
      .query[Ride]
      .option
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def findByStatus(status: RideStatus): Task[List[Ride]] = {
    sql"""
      SELECT
        id, client_id, creator_id, company_id, driver_id,
        pickup_datetime, scheduled_time, request_time, start_time, end_time,
        from_address, from_lat, from_lng,
        to_address, to_lat, to_lng,
        status, tariff_id,
        estimated_price_amount, final_price_amount,
        notes, specifics
      FROM rides
      WHERE status = $status
      ORDER BY request_time DESC
    """
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def findAll(): Task[List[Ride]] = {
    sql"""
      SELECT
        id, client_id, creator_id, company_id, driver_id,
        pickup_datetime, scheduled_time, request_time, start_time, end_time,
        from_address, from_lat, from_lng,
        to_address, to_lat, to_lng,
        status, tariff_id,
        estimated_price_amount, final_price_amount,
        notes, specifics
      FROM rides
      ORDER BY request_time DESC
    """
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  def findByClientId(clientId: PersonId): Task[List[Ride]] = {
    sql"""
      SELECT
        id, client_id, creator_id, company_id, driver_id,
        pickup_datetime, scheduled_time, request_time, start_time, end_time,
        from_address, from_lat, from_lng,
        to_address, to_lat, to_lng,
        status, tariff_id,
        estimated_price_amount, final_price_amount,
        notes, specifics
      FROM rides
      WHERE client_id = ${clientId.value}
      ORDER BY request_time DESC
    """
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  def findByDriverId(driverId: PersonId): Task[List[Ride]] = {
    sql"""
      SELECT
        id, client_id, creator_id, company_id, driver_id,
        pickup_datetime, scheduled_time, request_time, start_time, end_time,
        from_address, from_lat, from_lng,
        to_address, to_lat, to_lng,
        status, tariff_id,
        estimated_price_amount, final_price_amount,
        notes, specifics
      FROM rides
      WHERE driver_id = ${driverId.value}
      ORDER BY request_time DESC
    """
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def update(ride: Ride): Task[Ride] = {
    sql"""
      UPDATE rides SET
        driver_id = ${ride.driverId.map(_.value)},
        status = ${ride.status},
        start_time = ${ride.startTime},
        end_time = ${ride.endTime},
        final_price_amount = ${ride.finalPrice},
        notes = ${ride.notes},
        updated_at = NOW()
      WHERE id = ${ride.id.value}
    """.update.run
      .transact(xa)
      .as(ride)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def delete(id: RideId): Task[Unit] = {
    sql"""
      DELETE FROM rides WHERE id = ${id.value}
    """.update.run
      .transact(xa)
      .unit
      .mapError(ex => RideError.DatabaseError(ex))
  }

  implicit val rideRead: Read[Ride] =
    Read[
      (
          UUID,
          UUID,
          UUID,
          UUID,                 // id, client_id, creator_id, company_id
          Option[UUID],         // driver_id
          Instant,
          Option[Instant],
          Instant,
          Option[Instant],
          Option[Instant],      // pickup_datetime, scheduled_time, request_time, start_time, end_time
          String,
          Option[Double],
          Option[Double],       // from_address, from_lat, from_lng
          String,
          Option[Double],
          Option[Double],       // to_address, to_lat, to_lng
          RideStatus,
          Option[UUID],         // status, tariff_id
          Option[BigDecimal],
          Option[BigDecimal],   // estimated_price_amount, final_price_amount
          Option[String],
          Option[RideSpecifics] // notes, specifics
      )
    ].map {
      case (
            id,
            clientId,
            creatorId,
            companyId,
            driverId,
            pickupDateTime,
            scheduledTime,
            requestTime,
            startTime,
            endTime,
            fromAddress,
            fromLat,
            fromLng,
            toAddress,
            toLat,
            toLng,
            status,
            tariffId,
            estimatedPrice,
            finalPrice,
            notes,
            specifics
          ) =>
        Ride(
          id = RideId(id),
          clientId = PersonId(clientId),
          creatorId = PersonId(creatorId),
          companyId = CompanyId(companyId),
          driverId = driverId.map(PersonId.apply),
          status = status,
          pickupLocation = Location(
            address = fromAddress,
            latitude = fromLat,
            longitude = fromLng
          ),
          dropoffLocation = Location(
            address = toAddress,
            latitude = toLat,
            longitude = toLng
          ),
          scheduledTime = scheduledTime,
          requestTime = requestTime,
          startTime = startTime,
          endTime = endTime,
          tariffId = tariffId.map(TariffId.apply),
          estimatedPrice = estimatedPrice,
          finalPrice = finalPrice,
          notes = notes,
          specifics = specifics
        )
    }
}

object PostgresRideRepository {

  val layer: ZLayer[Transactor[Task], Nothing, RideRepository] = ZLayer.fromFunction((xa: Transactor[Task]) =>
    PostgresRideRepository(xa)
  )
}
