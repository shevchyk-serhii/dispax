package com.shevchyk.ride.repository

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.{
  AirportCheckpoint,
  DriverEarnings,
  FlightStatusRow,
  Ride,
  RideError,
  RideSpecifics,
  RideStatus,
  PaymentStatus,
  PaymentMethod,
  VehicleClass
}
import cats.data.NonEmptyList
import cats.syntax.apply.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.Instant
import java.util.UUID

final class PostgresRideRepository(xa: Transactor[Task]) extends RideRepository {

  // Import Circe codecs from domain
  import io.circe.{Encoder, Decoder}
  import RideSpecifics.{given Encoder[RideSpecifics], given Decoder[RideSpecifics]}

  // Get + Put for RideSpecifics JSONB — doobie derives Read[Option[RideSpecifics]] from Get[RideSpecifics] automatically
  implicit val rideSpecificsGet: Get[RideSpecifics] = {
    import io.circe.parser
    import org.postgresql.util.PGobject
    import cats.data.NonEmptyList
    Get.Advanced
      .other[PGobject](NonEmptyList.of("jsonb"))
      .tmap { pgo =>
        parser.parse(pgo.getValue).flatMap(_.as[RideSpecifics]) match {
          case Right(value) => value
          case Left(err)    => throw new RuntimeException(s"Failed to decode RideSpecifics: $err")
        }
      }
  }

  implicit val rideSpecificsPut: Put[RideSpecifics] = {
    import io.circe.syntax.*
    import org.postgresql.util.PGobject
    import cats.data.NonEmptyList
    Put.Advanced
      .other[PGobject](NonEmptyList.of("jsonb"))
      .tcontramap { spec =>
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
      case "Confirmed"  => RideStatus.Confirmed
      case "InProgress" => RideStatus.InProgress
      case "Completed"  => RideStatus.Completed
      case "Cancelled"  => RideStatus.Cancelled
      case "HandedOff"  => RideStatus.HandedOff
    },
    {
      case RideStatus.Requested  => "Requested"
      case RideStatus.Assigned   => "Assigned"
      case RideStatus.Confirmed  => "Confirmed"
      case RideStatus.InProgress => "InProgress"
      case RideStatus.Completed  => "Completed"
      case RideStatus.Cancelled  => "Cancelled"
      case RideStatus.HandedOff  => "HandedOff"
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

  implicit val airportCheckpointMeta: Meta[AirportCheckpoint] =
    Meta[String].imap { s =>
      AirportCheckpoint
        .fromString(s)
        .getOrElse(
          throw new RuntimeException(s"Unknown airport_checkpoint value: $s")
        )
    }(AirportCheckpoint.toDbString)

  // Postgres text[] <-> List[String] for ride tags (mirrors personRoleListMeta in the core repo).
  implicit val tagsListMeta: Meta[List[String]] = Meta[Array[String]].imap(_.toList)(_.toArray)

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
        notes, specifics, special_requirements,
        payment_status, payment_method, paid_at,
        cancellation_reason, cancellation_fee, cancelled_by,
        is_vip_ride, preferred_driver_used,
        pool_id, tariff_id, schedule_day_id, invoice_id, vehicle_class,
        external_driver_id, partner_company_id,
        confirmed_at, rejection_reason, rejected_by, rejected_at,
        tags
      ) VALUES (
        ${ride.id.value}, ${ride.clientId.value}, ${ride.creatorId.value}, ${ride.companyId.value}, ${ride.driverId.map(
        _.value
      )},
        ${ride.pickupDateTime}, ${ride.scheduledTime}, ${ride.requestTime}, ${ride.startTime}, ${ride.endTime},
        ${ride.pickupLocation.address}, ${ride.pickupLocation.latitude}, ${ride.pickupLocation.longitude},
        ${ride.dropoffLocation.address}, ${ride.dropoffLocation.latitude}, ${ride.dropoffLocation.longitude},
        ${ride.status},
        ${ride.estimatedPrice}, ${"EUR"},
        ${ride.finalPrice}, ${"EUR"},
        ${ride.notes}, ${ride.specifics}, ${ride.specialRequirements},
        ${ride.paymentStatus}, ${ride.paymentMethod}, ${ride.paidAt},
        ${ride.cancellationReason}, ${ride.cancellationFee}, ${ride.cancelledBy.map(_.value)},
        ${ride.isVipRide}, ${ride.preferredDriverUsed},
        ${ride.poolId.map(_.value)}, ${ride.tariffId.map(_.value)}, ${ride.scheduleDayId}, ${ride.invoiceId},
        ${VehicleClass.toDbString(ride.vehicleClass)},
        ${ride.externalDriverId.map(_.value)}, ${ride.partnerCompanyId.map(_.value)},
        ${ride.confirmedAt}, ${ride.rejectionReason}, ${ride.rejectedBy.map(_.value)}, ${ride.rejectedAt},
        ${ride.tags}
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
        is_vip_ride, preferred_driver_used,
        special_requirements, pool_id,
        schedule_day_id, invoice_id,
        flight_is_arrival, airport_checkpoint,
        vehicle_class,
        external_driver_id, partner_company_id,
        confirmed_at, rejection_reason, rejected_by, rejected_at,
        tags"""
  // NOTE: columns are listed explicitly (not SELECT *) to guarantee order matches rideReadBase/rideReadExtra/rideReadTags

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

  override def findByStatusAndCompany(status: RideStatus, companyId: CompanyId): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++
      fr"FROM rides WHERE status = $status AND company_id = ${companyId.value} ORDER BY request_time DESC")
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

  def findByDriverIdAndCompany(driverId: PersonId, companyId: CompanyId): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++
      fr"FROM rides WHERE driver_id = ${driverId.value} AND company_id = ${companyId.value} ORDER BY request_time DESC")
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  def findByClientIdAndCompany(clientId: PersonId, companyId: CompanyId): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++
      fr"FROM rides WHERE client_id = ${clientId.value} AND company_id = ${companyId.value} ORDER BY request_time DESC")
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

  def findByCompanyIdPaginated(companyId: CompanyId, offset: Int, limit: Int): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++ fr"FROM rides WHERE company_id = ${companyId.value}" ++
      fr"ORDER BY request_time DESC LIMIT $limit OFFSET $offset")
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  def findByDriverIdPaginated(driverId: PersonId, offset: Int, limit: Int): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++ fr"FROM rides WHERE driver_id = ${driverId.value}" ++
      fr"ORDER BY request_time DESC LIMIT $limit OFFSET $offset")
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  def findByDriverIdAndCompanyPaginated(
      driverId: PersonId,
      companyId: CompanyId,
      offset: Int,
      limit: Int
  ): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++
      fr"FROM rides WHERE driver_id = ${driverId.value} AND company_id = ${companyId.value}" ++
      fr"ORDER BY request_time DESC LIMIT $limit OFFSET $offset")
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  // Full SET clause shared by `update` and `updateIfStatus` so the two never drift apart on which
  // columns they persist. `updateIfStatus` adds a status guard to the WHERE; otherwise both write
  // the entire ride. (A previous version of `updateIfStatus` only set 4 columns, which silently
  // dropped start_time/cancellation_*/payment_* on the transitions that go through it.)
  private def rideSetClause(ride: Ride): Fragment =
    fr"""SET
      driver_id = ${ride.driverId.map(_.value)},
      status = ${ride.status},
      from_address = ${ride.pickupLocation.address},
      from_lat = ${ride.pickupLocation.latitude},
      from_lng = ${ride.pickupLocation.longitude},
      to_address = ${ride.dropoffLocation.address},
      to_lat = ${ride.dropoffLocation.latitude},
      to_lng = ${ride.dropoffLocation.longitude},
      pickup_datetime = ${ride.pickupDateTime},
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
      special_requirements = ${ride.specialRequirements},
      pool_id = ${ride.poolId.map(_.value)},
      tariff_id = ${ride.tariffId.map(_.value)},
      estimated_price_amount = ${ride.estimatedPrice},
      schedule_day_id = ${ride.scheduleDayId},
      invoice_id = ${ride.invoiceId},
      external_driver_id = ${ride.externalDriverId.map(_.value)},
      partner_company_id = ${ride.partnerCompanyId.map(_.value)},
      confirmed_at = ${ride.confirmedAt},
      rejection_reason = ${ride.rejectionReason},
      rejected_by = ${ride.rejectedBy.map(_.value)},
      rejected_at = ${ride.rejectedAt},
      tags = ${ride.tags},
      updated_at = NOW()"""

  override def update(ride: Ride): Task[Ride] =
    (fr"UPDATE rides" ++ rideSetClause(ride) ++ fr"WHERE id = ${ride.id.value}").update.run
      .transact(xa)
      .as(ride)
      .mapError(ex => RideError.DatabaseError(ex))

  override def updateIfStatus(ride: Ride, expectedStatuses: Set[RideStatus]): Task[Boolean] = {
    val whereStatus =
      expectedStatuses.toList match {
        case Nil          => fr"TRUE"
        case head :: tail => Fragments.in(fr"status", NonEmptyList(head, tail))
      }
    (fr"UPDATE rides" ++ rideSetClause(ride) ++ fr"WHERE id = ${ride.id.value} AND" ++ whereStatus).update.run
      .transact(xa)
      .map(_ > 0)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def markPaidIfCompleted(rideId: RideId, paymentMethod: Option[PaymentMethod]): Task[Boolean] =
    // Field-level CAS: only this UPDATE touches the payment columns, and the WHERE guard makes the
    // whole operation atomic in the DB. The `payment_status <> 'Paid'` predicate makes a second
    // concurrent markPaid a no-op (idempotent) instead of overwriting the winner's paid_at/method.
    sql"""UPDATE rides
          SET payment_status = ${PaymentStatus.Paid},
              payment_method = $paymentMethod,
              paid_at = NOW(),
              updated_at = NOW()
          WHERE id = ${rideId.value}
            AND status = ${RideStatus.Completed}
            AND payment_status <> ${PaymentStatus.Paid}""".update.run
      .transact(xa)
      .map(_ > 0)
      .mapError(ex => RideError.DatabaseError(ex))

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

  override def earningsByDriver(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant
  ): Task[DriverEarnings] = {
    sql"""
      SELECT
        COALESCE(SUM(COALESCE(final_price_amount, estimated_price_amount, 0))
                 FILTER (WHERE status = 'Completed'), 0),
        COUNT(*) FILTER (WHERE status = 'Completed')::int,
        COUNT(*) FILTER (WHERE status = 'Cancelled')::int
      FROM rides
      WHERE driver_id = ${driverId.value}
        AND company_id = ${companyId.value}
        AND COALESCE(end_time, pickup_datetime) >= $from
        AND COALESCE(end_time, pickup_datetime) < $to
    """
      .query[(BigDecimal, Int, Int)]
      .unique
      .map { case (gross, completed, cancelled) => DriverEarnings(gross, completed, cancelled) }
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def earningsBucketsByDriver(
      driverId: PersonId,
      companyId: CompanyId,
      from: Instant,
      to: Instant,
      bucket: TimeBucket
  ): Task[List[(Instant, BigDecimal)]] = {
    val truncUnit =
      bucket match
        case TimeBucket.Hour => "hour"
        case TimeBucket.Day  => "day"
    fr"""
      SELECT date_trunc($truncUnit, COALESCE(end_time, pickup_datetime)) AS bucket,
             COALESCE(SUM(COALESCE(final_price_amount, estimated_price_amount, 0)), 0)
      FROM rides
      WHERE driver_id = ${driverId.value}
        AND company_id = ${companyId.value}
        AND status = 'Completed'
        AND COALESCE(end_time, pickup_datetime) >= $from
        AND COALESCE(end_time, pickup_datetime) < $to
      GROUP BY bucket
      ORDER BY bucket
    """
      .query[(Instant, BigDecimal)]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def delete(id: RideId, companyId: CompanyId): Task[Unit] = {
    sql"""
      DELETE FROM rides WHERE id = ${id.value} AND company_id = ${companyId.value}
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
        Option[Instant],           // payment_status, payment_method, paid_at
        Option[String],
        Option[BigDecimal],
        Option[UUID],              // cancellation_reason, cancellation_fee, cancelled_by
        Boolean,
        Boolean,                   // is_vip_ride, preferred_driver_used
        Option[String],
        Option[UUID],              // special_requirements, pool_id
        Option[UUID],
        Option[UUID],              // schedule_day_id, invoice_id
        Option[Boolean],
        Option[AirportCheckpoint], // flight_is_arrival, airport_checkpoint
        Option[String],            // vehicle_class
        Option[UUID],
        Option[UUID],              // external_driver_id, partner_company_id
        Option[Instant],
        Option[String],
        Option[UUID],
        Option[Instant]            // confirmed_at, rejection_reason, rejected_by, rejected_at
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
          Boolean,
          Option[String],
          Option[UUID],
          Option[UUID],
          Option[UUID],
          Option[Boolean],
          Option[AirportCheckpoint],
          Option[String],
          Option[UUID],
          Option[UUID],
          Option[Instant],
          Option[String],
          Option[UUID],
          Option[Instant]
      )
    ]

  // Tags live in a third Read fragment rather than a 22nd element of rideReadExtra: rideReadBase is
  // already at Scala 3's 22-tuple limit and rideReadExtra has 21 elements, so adding here would leave
  // no headroom. A separate single-column fragment keeps existing positions stable and extensible.
  private val rideReadTags: Read[List[String]] = Read[List[String]]

  implicit val rideRead: Read[Ride] = (rideReadBase, rideReadExtra, rideReadTags).mapN {
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
            preferredDriverUsed,
            specialRequirements,
            poolId,
            scheduleDayId,
            invoiceId,
            flightIsArrival,
            airportCheckpoint,
            vehicleClassStr,
            externalDriverId,
            partnerCompanyId,
            confirmedAt,
            rejectionReason,
            rejectedBy,
            rejectedAt
          ),
          tags
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
        specialRequirements = specialRequirements,
        paymentStatus = paymentStatus.getOrElse(PaymentStatus.Unpaid),
        paymentMethod = paymentMethod,
        paidAt = paidAt,
        cancellationReason = cancellationReason,
        cancellationFee = cancellationFee,
        cancelledBy = cancelledBy.map(PersonId.apply),
        isVipRide = isVipRide,
        preferredDriverUsed = preferredDriverUsed,
        poolId = poolId.map(RidePoolId.apply),
        scheduleDayId = scheduleDayId,
        invoiceId = invoiceId,
        flightIsArrival = flightIsArrival,
        airportCheckpoint = airportCheckpoint,
        vehicleClass = vehicleClassStr.flatMap(VehicleClass.fromString).getOrElse(VehicleClass.Default),
        externalDriverId = externalDriverId.map(ExternalDriverId.apply),
        partnerCompanyId = partnerCompanyId.map(PartnerCompanyId.apply),
        confirmedAt = confirmedAt,
        rejectionReason = rejectionReason,
        rejectedBy = rejectedBy.map(PersonId.apply),
        rejectedAt = rejectedAt,
        tags = tags
      )
  }

  override def clearReminders(rideId: RideId): Task[Unit] =
    sql"""DELETE FROM sent_reminders WHERE ride_id = ${rideId.value}""".update.run
      .transact(xa)
      .unit
      .mapError(ex => RideError.DatabaseError(ex))

  override def updateCheckpoint(rideId: RideId, checkpoint: AirportCheckpoint): Task[Boolean] = {
    // Atomic forward-only guard: only advance if the new checkpoint's ordinal is strictly greater
    // than the current one.  We map the varchar names to integer ordinals via a CASE expression
    // because lexical order ('arrivals_hall' < 'landed' < 'terminal_exit') does not match ordinal
    // order (landed=0, arrivals_hall=1, terminal_exit=2).
    val newStr = AirportCheckpoint.toDbString(checkpoint)
    val newOrd = checkpoint.ordinal
    sql"""UPDATE rides
          SET airport_checkpoint = $newStr
          WHERE id = ${rideId.value}
            AND (
              airport_checkpoint IS NULL
              OR CASE airport_checkpoint
                   WHEN 'landed'        THEN 0
                   WHEN 'arrivals_hall' THEN 1
                   WHEN 'terminal_exit' THEN 2
                   ELSE -1
                 END < $newOrd
            )""".update.run
      .transact(xa)
      .map(_ > 0)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def updateFlightStatus(
      rideId: RideId,
      gate: Option[String],
      terminal: Option[String],
      flightStatus: Option[String],
      flightTime: Option[Instant],
      scheduledTime: Option[Instant]
  ): Task[Boolean] =
    sql"""UPDATE rides
          SET flight_gate = $gate,
              flight_terminal = $terminal,
              flight_status = $flightStatus,
              flight_time = $flightTime,
              flight_scheduled_time = $scheduledTime,
              updated_at = NOW()
          WHERE id = ${rideId.value}""".update.run
      .transact(xa)
      .map(_ > 0)
      .mapError(ex => RideError.DatabaseError(ex))

  override def findFlightStatus(rideId: RideId): Task[Option[FlightStatusRow]] =
    sql"""SELECT flight_gate, flight_terminal, flight_status, flight_time, flight_scheduled_time
          FROM rides WHERE id = ${rideId.value}"""
      .query[(Option[String], Option[String], Option[String], Option[Instant], Option[Instant])]
      .option
      .transact(xa)
      .map(_.map { case (gate, terminal, status, time, scheduled) =>
        FlightStatusRow(gate, terminal, status, time, scheduled)
      })
      .mapError(ex => RideError.DatabaseError(ex))

  override def findFlightStatusFor(rideIds: List[RideId]): Task[Map[RideId, FlightStatusRow]] =
    rideIds match
      case Nil          => ZIO.succeed(Map.empty)
      case head :: tail =>
        val ids = NonEmptyList(head, tail).map(_.value)
        (fr"""SELECT id, flight_gate, flight_terminal, flight_status, flight_time, flight_scheduled_time
              FROM rides WHERE""" ++ Fragments.in(fr"id", ids))
          .query[(UUID, Option[String], Option[String], Option[String], Option[Instant], Option[Instant])]
          .to[List]
          .transact(xa)
          .map(_.map { case (id, gate, terminal, status, time, scheduled) =>
            RideId(id) -> FlightStatusRow(gate, terminal, status, time, scheduled)
          }.toMap)
          .mapError(ex => RideError.DatabaseError(ex))

  override def findAssignedRidesInWindow(from: Instant, to: Instant): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++
      fr"""FROM rides
           WHERE status = 'Assigned'
             AND driver_id IS NOT NULL
             AND pickup_datetime > $from
             AND pickup_datetime <= $to
        """)
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def findActiveRidesInWindow(from: Instant, to: Instant): Task[List[Ride]] = {
    // Any not-yet-finished ride (incl. Requested, no driver) so the flight monitor can
    // enrich gate/terminal/status before assignment. Completed/Cancelled are excluded.
    (fr"SELECT" ++ rideColumns ++
      fr"""FROM rides
           WHERE status NOT IN ('Completed', 'Cancelled')
             AND pickup_datetime > $from
             AND pickup_datetime <= $to
        """)
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  override def findRidesNeedingConfirmation(from: Instant, to: Instant): Task[List[Ride]] = {
    (fr"SELECT" ++ rideColumns ++
      fr"""FROM rides
           WHERE status = 'Assigned'
             AND driver_id IS NOT NULL
             AND pickup_datetime >= $from
             AND pickup_datetime < $to
        """)
      .query[Ride]
      .to[List]
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))
  }

  // ---------------------------------------------------------------------------
  // Platform-level (cross-tenant) analytics — SuperAdmin only.
  // No company_id filter in these queries; names make the cross-tenant intent explicit.
  // ---------------------------------------------------------------------------

  override def countAllRidesByStatus(): Task[Map[String, Int]] =
    sql"""
      SELECT status::text, COUNT(*)::int
      FROM rides
      GROUP BY status
    """
      .query[(String, Int)]
      .to[List]
      .transact(xa)
      .map(_.toMap)
      .mapError(ex => RideError.DatabaseError(ex))

  override def sumAllRevenue(from: Instant, to: Instant): Task[BigDecimal] =
    sql"""
      SELECT COALESCE(SUM(COALESCE(final_price_amount, estimated_price_amount, 0)), 0)
      FROM rides
      WHERE status = 'Completed'
        AND end_time >= $from
        AND end_time <= $to
    """
      .query[BigDecimal]
      .unique
      .transact(xa)
      .mapError(ex => RideError.DatabaseError(ex))

  override def countRidesByCompany(from: Instant, to: Instant): Task[Map[java.util.UUID, Int]] =
    sql"""
      SELECT company_id, COUNT(*)::int
      FROM rides
      WHERE request_time >= $from
        AND request_time <= $to
      GROUP BY company_id
    """
      .query[(java.util.UUID, Int)]
      .to[List]
      .transact(xa)
      .map(_.toMap)
      .mapError(ex => RideError.DatabaseError(ex))

  override def sumRevenueByCompanyPlatform(from: Instant, to: Instant): Task[Map[java.util.UUID, BigDecimal]] =
    sql"""
      SELECT company_id, COALESCE(SUM(COALESCE(final_price_amount, estimated_price_amount, 0)), 0)
      FROM rides
      WHERE status = 'Completed'
        AND end_time >= $from
        AND end_time <= $to
      GROUP BY company_id
    """
      .query[(java.util.UUID, BigDecimal)]
      .to[List]
      .transact(xa)
      .map(_.toMap)
      .mapError(ex => RideError.DatabaseError(ex))
}

object PostgresRideRepository {

  val layer: ZLayer[Transactor[Task], Nothing, RideRepository] = ZLayer.fromFunction((xa: Transactor[Task]) =>
    PostgresRideRepository(xa)
  )
}
