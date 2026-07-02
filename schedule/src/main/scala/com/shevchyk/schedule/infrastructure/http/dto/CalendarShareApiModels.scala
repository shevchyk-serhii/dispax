package com.shevchyk.schedule.infrastructure.http.dto

import com.shevchyk.schedule.application.{CalendarShareGrantView, SharedCalendar}
import com.shevchyk.schedule.domain.CalendarShareInvite
import sttp.tapir.Schema
import zio.json.*

// -- Invites -----------------------------------------------------------------

/**
 * Request body for minting an invite. `expiresInDays` is clamped server-side to 1..30 (default 7).
 */
case class CreateCalendarShareInviteApiRequest(expiresInDays: Option[Int] = None) derives JsonCodec

object CreateCalendarShareInviteApiRequest:
  given Schema[CreateCalendarShareInviteApiRequest] = Schema.derived

/**
 * The invite as returned to its creator — includes the redeemable code.
 */
case class CalendarShareInviteDto(
    id: String,
    code: String,
    createdAt: String,
    expiresAt: String
) derives JsonCodec

object CalendarShareInviteDto:

  given Schema[CalendarShareInviteDto] = Schema.derived

  def fromDomain(invite: CalendarShareInvite): CalendarShareInviteDto = CalendarShareInviteDto(
    id = invite.id.value.toString,
    code = invite.token,
    createdAt = invite.createdAt.toString,
    expiresAt = invite.expiresAt.toString
  )

// -- Redeem ------------------------------------------------------------------

case class RedeemCalendarShareApiRequest(code: String) derives JsonCodec

object RedeemCalendarShareApiRequest:
  given Schema[RedeemCalendarShareApiRequest] = Schema.derived

// -- Grants ------------------------------------------------------------------

/**
 * A grant as shown in list screens. Exposes only the counterparties' display names and company names — both parties
 * explicitly connected via an invite code, so this is the agreed minimum for a usable list.
 */
case class CalendarShareGrantDto(
    id: String,
    grantorName: String,
    grantorCompanyName: String,
    granteeName: String,
    granteeCompanyName: String,
    createdAt: String
) derives JsonCodec

object CalendarShareGrantDto:

  given Schema[CalendarShareGrantDto] = Schema.derived

  def fromView(view: CalendarShareGrantView): CalendarShareGrantDto = CalendarShareGrantDto(
    id = view.grant.id.value.toString,
    grantorName = view.grantorName,
    grantorCompanyName = view.grantorCompanyName,
    granteeName = view.granteeName,
    granteeCompanyName = view.granteeCompanyName,
    createdAt = view.grant.createdAt.toString
  )

// -- Shared calendar (the PII firewall lives in this DTO's shape) --------------

/**
 * A shift as visible across companies: date, times and status only — notes are deliberately absent (they may carry
 * client PII).
 */
case class SharedShiftDto(
    date: String,
    startTime: String,
    endTime: String,
    status: String
) derives JsonCodec

object SharedShiftDto:
  given Schema[SharedShiftDto] = Schema.derived

/**
 * A busy interval as visible across companies: two instants and a kind ("Ride" | "Unavailability") — no client,
 * address, price, reason or note ever crosses this boundary.
 */
case class SharedBusySlotDto(
    start: String,
    end: String,
    kind: String
) derives JsonCodec

object SharedBusySlotDto:
  given Schema[SharedBusySlotDto] = Schema.derived

case class SharedCalendarDto(
    grantId: String,
    grantorName: String,
    shifts: List[SharedShiftDto],
    busySlots: List[SharedBusySlotDto]
) derives JsonCodec

object SharedCalendarDto:

  given Schema[SharedCalendarDto] = Schema.derived

  def fromDomain(calendar: SharedCalendar): SharedCalendarDto = SharedCalendarDto(
    grantId = calendar.grantId.value.toString,
    grantorName = calendar.grantorName,
    shifts = calendar.shifts.map(day =>
      SharedShiftDto(
        date = day.date.toString,
        startTime = day.startTime.toString,
        endTime = day.endTime.toString,
        status = day.status.toString
      )
    ),
    busySlots = calendar.busy.map(slot =>
      SharedBusySlotDto(
        start = slot.start.toString,
        end = slot.end.toString,
        kind = slot.kind.toString
      )
    )
  )
