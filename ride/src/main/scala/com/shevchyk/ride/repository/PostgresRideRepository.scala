package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.{Ride, RideError, RideSpecifics, RideStatus, PaymentStatus, PaymentMethod}
import cats.syntax.apply.*
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

  // Meta instance for JSONB RideSpecifics via PGobject string serialization
  implicit val rideSpecificsMeta: Meta[RideSpecifics] = {
    import io.circe.syntax.*
    import io.circe.parser
    import org.postgresql.util.PGobject
    Meta.Advanced
      .other[PGobject]("jsonb")
      .imap { pgo =>
        parser.parse(pgo.getValue).flatMap(_.as[RideSpecifics]) match {
          case Right(value) => value
          case Left(err)    => throw new RuntimeException(s"Failed to decode RideSpecifics: $err")
        }
      } { spec =>
        val pgo = new PGobject()
        pgo.setType("jsonb")
        pgo.setValue(spec.asJson.noSpaces)
        pgo
      }
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

  implicit val paymentStatusMeta: Meta[PaymentStatus] = pgEnumString(
    "payment_status",
    str => PaymentStatus.valueOf(str),
    _.toString
  )

  implicit val paymentMethodMeta: Meta[PaymentMethod] = pgEnumString(
    "payment_method",
    str => PaymentMethod.valueOf(str),
    _.toString
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
        notes, specifics,
        payment_status, payment_method, paid_at,
        cancellation_reason, cancellation_fee, cancelled_by,
        is_vip_ride, preferred_driver_used
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
        ${ride.notes}, ${ride.specifics},
        ${ride.paymentStatus}, ${ride.paymentMethod}, ${ride.paidAt},
        ${ride.cancellationReason}, ${ride.cancellationFee}, ${ride.cancelledBy.map(_.value)},
        ${ride.isVipRide}, ${ride.preferredDriverUsed}
      )
    """.update.run
      .transact(xa)
      .mapBoth(ex => RideError.DatabaseError(ex), _ => ride)
  }

  // Standard column list for all SELECT queries
  private val rideColumns =
    fr"""id, client_id, creator_id, company_id, driver_id,
        pickup_datetime, scheduled_time, request_time, start_time, end_time,
        from_address, from_lat, from_lng,
        to_address, to_lat, to_lng,
        status, tariff_id,
        estimated_price_amount, final_price_amount,
        notes, specifics,
        payment_status, payment_method, paid_at,
        cancellation_reason, cancellation_fee, cancelled_by,
        is_vip_ride, preferred_driver_used"""

  override def findById(id: RideId): Task[Option[Ride]] = {
    (fr"SELECT" ++ rideColumns ++ fr"FROM rides WHERE id = ${id.value}")
      .query[Ride]
      .option
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def findByStatus(status: RideStatus): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++ fr"FROM rides WHERE status = $status ORDER BY request_time DESC")
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def findAll(): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++ fr"FROM rides ORDER BY request_time DESC")
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  def findByClientId(clientId: PersonId): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++ fr"FROM rides WHERE client_id = ${clientId.value} ORDER BY request_time DESC")
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  def findByDriverId(driverId: PersonId): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++ fr"FROM rides WHERE driver_id = ${driverId.value} ORDER BY request_time DESC")
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  def findByCompanyId(companyId: CompanyId): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++ fr"FROM rides WHERE company_id = ${companyId.value} ORDER BY request_time DESC")
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
        from_address = ${ride.pickupLocation.address},
        from_lat = ${ride.pickupLocation.latitude},
        from_lng = ${ride.pickupLocation.longitude},
        to_address = ${ride.dropoffLocation.address},
        to_lat = ${ride.dropoffLocation.latitude},
        to_lng = ${ride.dropoffLocation.longitude},
        scheduled_time = ${ride.scheduledTime},
        start_time = ${ride.startTime},
        end_time = ${ride.endTime},
        final_price_amount = ${ride.finalPrice},
        notes = ${ride.notes},
        specifics = ${ride.specifics},
        payment_status = ${ride.paymentStatus},
        payment_method = ${ride.paymentMethod},
        paid_at = ${ride.paidAt},
        cancellation_reason = ${ride.cancellationReason},
        cancellation_fee = ${ride.cancellationFee},
        cancelled_by = ${ride.cancelledBy.map(_.value)},
        is_vip_ride = ${ride.isVipRide},
        preferred_driver_used = ${ride.preferredDriverUsed},
        updated_at = NOW()
      WHERE id = ${ride.id.value}
    """.update.run
      .transact(xa)
      .as(ride)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def countByCompanyGroupedByStatus(companyId: CompanyId): Task[Map[String, Int]] = {
    sql"""
      SELECT status::text, COUNT(*)::int
      FROM rides
      WHERE company_id = ${companyId.value}
      GROUP BY status
    """
      .query[(String, Int)]
      .to[List]
      .transact(xa)
      .map(_.toMap)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def sumRevenueByCompany(companyId: CompanyId): Task[BigDecimal] = {
    sql"""
      SELECT COALESCE(SUM(COALESCE(final_price_amount, estimated_price_amount, 0)), 0)
      FROM rides
      WHERE company_id = ${companyId.value} AND status = 'Completed'
    """
      .query[BigDecimal]
      .unique
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def sumTodayRevenueByCompany(companyId: CompanyId): Task[BigDecimal] = {
    sql"""
      SELECT COALESCE(SUM(COALESCE(final_price_amount, estimated_price_amount, 0)), 0)
      FROM rides
      WHERE company_id = ${companyId.value}
        AND status = 'Completed'
        AND end_time::date = CURRENT_DATE
    """
      .query[BigDecimal]
      .unique
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def avgAssignmentMinutesByCompany(companyId: CompanyId): Task[Double] = {
    sql"""
      SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (start_time - request_time)) / 60.0), 0)
      FROM rides
      WHERE company_id = ${companyId.value}
        AND start_time IS NOT NULL
        AND status IN ('Assigned', 'InProgress', 'Completed')
    """
      .query[Double]
      .unique
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def countDailyStatsByCompany(companyId: CompanyId, days: Int): Task[List[(String, Int, Int, Int)]] = {
    sql"""
      SELECT
        d::date::text AS date,
        COUNT(*) FILTER (WHERE r.status = 'Completed')::int AS completed,
        COUNT(*) FILTER (WHERE r.status = 'Cancelled')::int AS cancelled,
        COUNT(*)::int AS total
      FROM generate_series(CURRENT_DATE - ${days - 1} * INTERVAL '1 day', CURRENT_DATE, '1 day') AS d
      LEFT JOIN rides r ON r.company_id = ${companyId.value}
        AND r.request_time::date = d::date
      GROUP BY d
      ORDER BY d DESC
    """
      .query[(String, Int, Int, Int)]
      .to[List]
      .transact(xa)
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

  // Split into two Read instances and combine, because Scala 3 tuples max at 22 elements
  private val rideReadBase: Read[
    (
        UUID,
        UUID,
        UUID,
        UUID,
        Option[UUID],         // id, client_id, creator_id, company_id, driver_id
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
  ] =
    Read[
      (
          UUID,
          UUID,
          UUID,
          UUID,
          Option[UUID],
          Instant,
          Option[Instant],
          Instant,
          Option[Instant],
          Option[Instant],
          String,
          Option[Double],
          Option[Double],
          String,
          Option[Double],
          Option[Double],
          RideStatus,
          Option[UUID],
          Option[BigDecimal],
          Option[BigDecimal],
          Option[String],
          Option[RideSpecifics]
      )
    ]

  private val rideReadExtra: Read[
    (
        Option[PaymentStatus],
        Option[PaymentMethod],
        Option[Instant], // payment_status, payment_method, paid_at
        Option[String],
        Option[BigDecimal],
        Option[UUID],    // cancellation_reason, cancellation_fee, cancelled_by
        Boolean,
        Boolean          // is_vip_ride, preferred_driver_used
    )
  ] =
    Read[
      (
          Option[PaymentStatus],
          Option[PaymentMethod],
          Option[Instant],
          Option[String],
          Option[BigDecimal],
          Option[UUID],
          Boolean,
          Boolean
      )
    ]

  implicit val rideRead: Read[Ride] = (rideReadBase, rideReadExtra).mapN {
    case (
          (
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
          ),
          (
            paymentStatus,
            paymentMethod,
            paidAt,
            cancellationReason,
            cancellationFee,
            cancelledBy,
            isVipRide,
            preferredDriverUsed
          )
        ) =>
      Ride(
        id = RideId(id),
        clientId = PersonId(clientId),
        creatorId = PersonId(creatorId),
        companyId = CompanyId(companyId),
        driverId = driverId.map(PersonId.apply),
        status = status,
        pickupLocation = Location(address = fromAddress, latitude = fromLat, longitude = fromLng),
        dropoffLocation = Location(address = toAddress, latitude = toLat, longitude = toLng),
        pickupDateTime = pickupDateTime,
        scheduledTime = scheduledTime,
        requestTime = requestTime,
        startTime = startTime,
        endTime = endTime,
        tariffId = tariffId.map(TariffId.apply),
        estimatedPrice = estimatedPrice,
        finalPrice = finalPrice,
        notes = notes,
        specifics = specifics,
        paymentStatus = paymentStatus,
        paymentMethod = paymentMethod,
        paidAt = paidAt,
        cancellationReason = cancellationReason,
        cancellationFee = cancellationFee,
        cancelledBy = cancelledBy.map(PersonId.apply),
        isVipRide = isVipRide,
        preferredDriverUsed = preferredDriverUsed
      )
  }
}

object PostgresRideRepository {

  val layer: ZLayer[Transactor[Task], Nothing, RideRepository] = ZLayer.fromFunction((xa: Transactor[Task]) =>
    PostgresRideRepository(xa)
  )
}
