package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*
import java.time.Instant
import java.util.UUID

final class PostgresCompanySettingsRepository(xa: Transactor[Task]) extends CompanySettingsRepository:

  implicit val instantMeta: Meta[Instant] =
    Meta[java.time.OffsetDateTime].imap(_.toInstant)(instant =>
      java.time.OffsetDateTime.ofInstant(instant, java.time.ZoneOffset.UTC)
    )

  override def findByCompanyId(companyId: CompanyId): Task[Option[CompanySettings]] =
    sql"""
      SELECT company_id, commission_rate, working_hours_start::text, working_hours_end::text,
             default_currency, cancellation_fee_default, no_show_fee, auto_assign_enabled, updated_at,
             datev_beraternummer, datev_mandantennummer, datev_sachkontenlaenge,
             airport_buffer_minutes, airport_checkin_close_minutes
      FROM company_settings
      WHERE company_id = ${companyId.value}
    """
      .query[CompanySettings]
      .option
      .transact(xa)

  override def upsert(settings: CompanySettings): Task[CompanySettings] =
    sql"""
      INSERT INTO company_settings (company_id, commission_rate, working_hours_start, working_hours_end,
                                     default_currency, cancellation_fee_default, no_show_fee, auto_assign_enabled, updated_at,
                                     datev_beraternummer, datev_mandantennummer, datev_sachkontenlaenge,
                                     airport_buffer_minutes, airport_checkin_close_minutes)
      VALUES (${settings.companyId.value}, ${settings.commissionRate},
              ${settings.workingHoursStart}::time, ${settings.workingHoursEnd}::time,
              ${settings.defaultCurrency}, ${settings.cancellationFeeDefault}, ${settings.noShowFee},
              ${settings.autoAssignEnabled}, NOW(),
              ${settings.datevBeraternummer}, ${settings.datevMandantennummer}, ${settings.datevSachkontenlaenge},
              ${settings.airportBufferMinutes}, ${settings.airportCheckInCloseMinutes})
      ON CONFLICT (company_id) DO UPDATE SET
        commission_rate = ${settings.commissionRate},
        working_hours_start = ${settings.workingHoursStart}::time,
        working_hours_end = ${settings.workingHoursEnd}::time,
        default_currency = ${settings.defaultCurrency},
        cancellation_fee_default = ${settings.cancellationFeeDefault},
        no_show_fee = ${settings.noShowFee},
        auto_assign_enabled = ${settings.autoAssignEnabled},
        updated_at = NOW(),
        datev_beraternummer = ${settings.datevBeraternummer},
        datev_mandantennummer = ${settings.datevMandantennummer},
        datev_sachkontenlaenge = ${settings.datevSachkontenlaenge},
        airport_buffer_minutes = ${settings.airportBufferMinutes},
        airport_checkin_close_minutes = ${settings.airportCheckInCloseMinutes}
    """.update.run
      .transact(xa)
      .as(settings.copy(updatedAt = Instant.now()))

  implicit val settingsRead: Read[CompanySettings] =
    Read[
      (
          UUID,
          BigDecimal,
          String,
          String,
          String,
          BigDecimal,
          BigDecimal,
          Boolean,
          Instant,
          Option[String],
          Option[String],
          Option[Int],
          Option[Int],
          Option[Int]
      )
    ].map {
      case (
            companyId,
            commissionRate,
            workingHoursStart,
            workingHoursEnd,
            currency,
            cancellationFee,
            noShowFee,
            autoAssign,
            updatedAt,
            datevBeraternummer,
            datevMandantennummer,
            datevSachkontenlaenge,
            airportBufferMinutes,
            airportCheckInCloseMinutes
          ) =>
        CompanySettings(
          companyId = CompanyId(companyId),
          commissionRate = commissionRate,
          workingHoursStart = workingHoursStart,
          workingHoursEnd = workingHoursEnd,
          defaultCurrency = currency,
          cancellationFeeDefault = cancellationFee,
          noShowFee = noShowFee,
          autoAssignEnabled = autoAssign,
          updatedAt = updatedAt,
          datevBeraternummer = datevBeraternummer,
          datevMandantennummer = datevMandantennummer,
          datevSachkontenlaenge = datevSachkontenlaenge,
          airportBufferMinutes = airportBufferMinutes,
          airportCheckInCloseMinutes = airportCheckInCloseMinutes
        )
    }

object PostgresCompanySettingsRepository:

  val postgresLayer: ZLayer[Transactor[Task], Nothing, CompanySettingsRepository] = ZLayer.fromFunction(
    PostgresCompanySettingsRepository(_)
  )
