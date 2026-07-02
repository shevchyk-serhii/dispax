package com.shevchyk.schedule.application

import com.shevchyk.auth.middleware.RateLimiter
import com.shevchyk.core.application.DriverBusySlots
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{CompanyRepository, PersonRepository}
import com.shevchyk.schedule.domain.*
import com.shevchyk.schedule.repository.{
  CalendarShareGrantRepository,
  CalendarShareInviteRepository,
  ScheduleDayRepository
}
import com.shevchyk.schedule.repository.DriverUnavailabilityRepository
import zio.*

import java.time.{Instant, LocalDate, ZoneOffset}

/**
 * A grant enriched with counterparty display data for list screens. Only the counterparty's name and company name are
 * exposed — acceptable because both parties explicitly connected via an invite code.
 */
final case class CalendarShareGrantView(
    grant: CalendarShareGrant,
    grantorName: String,
    grantorCompanyName: String,
    granteeName: String,
    granteeCompanyName: String
)

enum SharedBusyKind:
  case Ride, Unavailability

/**
 * A PII-free busy interval in the grantor's calendar: two instants and what kind of block it is — nothing else.
 */
final case class SharedBusyInterval(start: Instant, end: Instant, kind: SharedBusyKind)

/**
 * The cross-company read model of a grantor's personal calendar. Shift notes are deliberately dropped (they may carry
 * client PII); busy intervals carry no ride/unavailability details.
 */
final case class SharedCalendar(
    grantId: CalendarShareGrantId,
    grantorName: String,
    shifts: List[ScheduleDay],
    busy: List[SharedBusyInterval]
)

trait CalendarShareService:

  /**
   * Mint a multi-use invite code for the caller's personal calendar. `expiresInDays` is clamped to 1..30 (default 7).
   */
  def createInvite(
      grantorId: PersonId,
      grantorCompanyId: CompanyId,
      expiresInDays: Option[Int]
  ): IO[CalendarShareError, CalendarShareInvite]

  def listMyInvites(grantorId: PersonId): IO[CalendarShareError, List[CalendarShareInvite]]

  def revokeInvite(id: CalendarShareInviteId, grantorId: PersonId): IO[CalendarShareError, Unit]

  /**
   * Redeem an invite code as the calling user, producing (or idempotently returning) an active grant, enriched with
   * display names. All token failures (unknown / expired / revoked / garbage) collapse to
   * [[CalendarShareError.InviteInvalid]].
   */
  def redeem(
      code: String,
      granteeId: PersonId,
      granteeCompanyId: CompanyId
  ): IO[CalendarShareError, CalendarShareGrantView]

  /**
   * Active grants where the caller is the grantor, enriched with display names.
   */
  def listGranted(grantorId: PersonId): IO[CalendarShareError, List[CalendarShareGrantView]]

  /**
   * Active grants where the caller is the grantee, enriched with display names.
   */
  def listSharedWithMe(granteeId: PersonId): IO[CalendarShareError, List[CalendarShareGrantView]]

  /**
   * Sever a grant from either side: the caller must be its grantor or its grantee; anything else is a 404-collapse.
   */
  def revokeGrant(id: CalendarShareGrantId, partyId: PersonId): IO[CalendarShareError, Unit]

  /**
   * The cross-company calendar read. The caller must be the grant's grantee and the grant must be active, otherwise
   * [[CalendarShareError.GrantNotFound]] (404 — never 403, no existence leak). Date range is inclusive and capped.
   */
  def getSharedCalendar(
      grantId: CalendarShareGrantId,
      callerId: PersonId,
      from: LocalDate,
      to: LocalDate
  ): IO[CalendarShareError, SharedCalendar]

class CalendarShareServiceImpl(
    inviteRepository: CalendarShareInviteRepository,
    grantRepository: CalendarShareGrantRepository,
    personRepository: PersonRepository,
    companyRepository: CompanyRepository,
    scheduleDayRepository: ScheduleDayRepository,
    unavailabilityRepository: DriverUnavailabilityRepository,
    driverBusySlots: DriverBusySlots,
    redeemRateLimiter: RateLimiter
) extends CalendarShareService:

  import CalendarShareServiceImpl.*

  override def createInvite(
      grantorId: PersonId,
      grantorCompanyId: CompanyId,
      expiresInDays: Option[Int]
  ): IO[CalendarShareError, CalendarShareInvite] =
    for {
      now    <- Clock.instant
      active <- inviteRepository.findActiveByGrantor(grantorId, now).mapDbError
      _      <- ZIO.fail(CalendarShareError.TooManyActiveInvites).when(active.size >= MaxActiveInvites)
      days    = expiresInDays.getOrElse(DefaultInviteExpiryDays).max(1).min(MaxInviteExpiryDays)
      invite  = CalendarShareInvite(
                  id = CalendarShareInviteId.generate(),
                  token = CalendarShareInvite.generateTokenValue(),
                  grantorPersonId = grantorId,
                  grantorCompanyId = grantorCompanyId,
                  createdAt = now,
                  expiresAt = now.plusSeconds(days.toLong * 24 * 3600),
                  revokedAt = None
                )
      saved  <- inviteRepository.create(invite).mapDbError
    } yield saved

  override def listMyInvites(grantorId: PersonId): IO[CalendarShareError, List[CalendarShareInvite]] = Clock.instant
    .flatMap(now => inviteRepository.findActiveByGrantor(grantorId, now).mapDbError)

  override def revokeInvite(id: CalendarShareInviteId, grantorId: PersonId): IO[CalendarShareError, Unit] =
    for {
      now     <- Clock.instant
      revoked <- inviteRepository.revoke(id, grantorId, now).mapDbError
      _       <- ZIO.fail(CalendarShareError.InviteNotFound(id)).unless(revoked)
    } yield ()

  override def redeem(
      code: String,
      granteeId: PersonId,
      granteeCompanyId: CompanyId
  ): IO[CalendarShareError, CalendarShareGrantView] =
    for {
      allowed   <- redeemRateLimiter.checkRate(s"calendar-share-redeem:${granteeId.value}")
      _         <- ZIO.fail(CalendarShareError.RateLimited).unless(allowed)
      // Syntactic pre-check: garbage never reaches the database, and collapses to the same 404 as unknown tokens.
      _         <- ZIO.fail(CalendarShareError.InviteInvalid).unless(CalendarShareInvite.isPlausibleToken(code.trim))
      now       <- Clock.instant
      inviteOpt <- inviteRepository.findByToken(code.trim).mapDbError
      invite    <- ZIO
                     .fromOption(inviteOpt.filter(_.isActive(now)))
                     .orElseFail(CalendarShareError.InviteInvalid)
      _         <- ZIO.fail(CalendarShareError.SelfShareNotAllowed).when(invite.grantorPersonId == granteeId)
      existing  <- grantRepository.findActivePair(invite.grantorPersonId, granteeId).mapDbError
      grant     <-
        existing match
          case Some(g) => ZIO.succeed(g) // idempotent: redeeming twice returns the same grant
          case None    => insertGrant(invite, granteeId, granteeCompanyId, now)
      views     <- enrich(List(grant))
      view      <- ZIO
                     .fromOption(views.headOption)
                     .orElseFail(CalendarShareError.DatabaseError(new RuntimeException("Failed to enrich grant")))
    } yield view

  private def insertGrant(
      invite: CalendarShareInvite,
      granteeId: PersonId,
      granteeCompanyId: CompanyId,
      now: Instant
  ): IO[CalendarShareError, CalendarShareGrant] =
    for {
      count <- grantRepository.countActiveByGrantor(invite.grantorPersonId).mapDbError
      _     <- ZIO.fail(CalendarShareError.TooManyActiveGrants).when(count >= MaxActiveGrantsPerGrantor)
      grant  = CalendarShareGrant(
                 id = CalendarShareGrantId.generate(),
                 inviteId = Some(invite.id),
                 grantorPersonId = invite.grantorPersonId,
                 grantorCompanyId = invite.grantorCompanyId,
                 granteePersonId = granteeId,
                 granteeCompanyId = granteeCompanyId,
                 createdAt = now,
                 expiresAt = None,
                 revokedAt = None
               )
      saved <- grantRepository
                 .create(grant)
                 .catchAll(_ =>
                   // Unique-violation race: a concurrent redeem of the same pair won — return that grant instead.
                   grantRepository
                     .findActivePair(invite.grantorPersonId, granteeId)
                     .mapDbError
                     .someOrFail(CalendarShareError.DatabaseError(new RuntimeException("Failed to create grant")))
                 )
    } yield saved

  override def listGranted(grantorId: PersonId): IO[CalendarShareError, List[CalendarShareGrantView]] = grantRepository
    .findActiveByGrantor(grantorId)
    .mapDbError
    .flatMap(enrich)

  override def listSharedWithMe(granteeId: PersonId): IO[CalendarShareError, List[CalendarShareGrantView]] =
    grantRepository.findActiveByGrantee(granteeId).mapDbError.flatMap(enrich)

  override def revokeGrant(id: CalendarShareGrantId, partyId: PersonId): IO[CalendarShareError, Unit] =
    for {
      now     <- Clock.instant
      revoked <- grantRepository.revoke(id, partyId, now).mapDbError
      _       <- ZIO.fail(CalendarShareError.GrantNotFound(id)).unless(revoked)
    } yield ()

  override def getSharedCalendar(
      grantId: CalendarShareGrantId,
      callerId: PersonId,
      from: LocalDate,
      to: LocalDate
  ): IO[CalendarShareError, SharedCalendar] =
    for {
      _        <- ZIO
                    .fail(CalendarShareError.ValidationError("'from' must not be after 'to'"))
                    .when(from.isAfter(to))
      _        <- ZIO
                    .fail(CalendarShareError.ValidationError(s"Date range too large (max $MaxRangeDays days)"))
                    .when(to.toEpochDay - from.toEpochDay >= MaxRangeDays)
      now      <- Clock.instant
      grantOpt <- grantRepository.findById(grantId).mapDbError
      // Foreign, revoked and expired grants all collapse to the same 404 — no existence leak.
      grant    <- ZIO
                    .fromOption(grantOpt.filter(g => g.granteePersonId == callerId && g.isActive(now)))
                    .orElseFail(CalendarShareError.GrantNotFound(grantId))
      grantor  <- personRepository.findById(grant.grantorPersonId).mapDbError
      // A deactivated (or deleted) grantor's calendar goes dark rather than leaking why.
      person   <- ZIO
                    .fromOption(grantor.filter(_.status == UserStatus.ACTIVE))
                    .orElseFail(CalendarShareError.GrantNotFound(grantId))
      shifts   <- scheduleDayRepository
                    .findByDriverId(grant.grantorPersonId)
                    .mapDbError
                    .map(_.filter(d => !d.date.isBefore(from) && !d.date.isAfter(to)))
      fromI     = from.atStartOfDay(ZoneOffset.UTC).toInstant
      toI       = to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant
      rideBusy <- driverBusySlots.slots(grant.grantorPersonId, fromI, toI).mapDbError
      unavail  <-
        unavailabilityRepository
          .findOverlapping(grant.grantorPersonId, grant.grantorCompanyId, fromI, toI)
          .mapDbError
      busy      =
        rideBusy.map(s => SharedBusyInterval(s.start, s.end, SharedBusyKind.Ride)) ++
          unavail.map(u => SharedBusyInterval(u.fromTime, u.toTime, SharedBusyKind.Unavailability))
    } yield SharedCalendar(
      grantId = grant.id,
      grantorName = person.name,
      shifts = shifts.sortBy(_.date.toEpochDay),
      busy = busy.sortBy(_.start)
    )

  // -- Display-name enrichment ----------------------------------------------

  private def enrich(grants: List[CalendarShareGrant]): IO[CalendarShareError, List[CalendarShareGrantView]] =
    val personIds  = grants.flatMap(g => List(g.grantorPersonId, g.granteePersonId)).distinct
    val companyIds = grants.flatMap(g => List(g.grantorCompanyId, g.granteeCompanyId)).distinct
    for {
      persons   <- ZIO
                     .foreach(personIds)(id => personRepository.findById(id).mapDbError.map(id -> _))
                     .map(_.toMap)
      companies <- ZIO
                     .foreach(companyIds)(id => companyRepository.findById(id).mapDbError.map(id -> _))
                     .map(_.toMap)
    } yield grants.map { g =>
      CalendarShareGrantView(
        grant = g,
        grantorName = persons.get(g.grantorPersonId).flatten.map(_.name).getOrElse(DeletedPlaceholder),
        grantorCompanyName = companies.get(g.grantorCompanyId).flatten.map(_.name).getOrElse(DeletedPlaceholder),
        granteeName = persons.get(g.granteePersonId).flatten.map(_.name).getOrElse(DeletedPlaceholder),
        granteeCompanyName = companies.get(g.granteeCompanyId).flatten.map(_.name).getOrElse(DeletedPlaceholder)
      )
    }

  extension [A](task: Task[A])

    private def mapDbError: IO[CalendarShareError, A] = task.mapError {
      case e: CalendarShareError => e
      case ex                    => CalendarShareError.DatabaseError(ex)
    }

object CalendarShareServiceImpl:

  val MaxActiveInvites: Int          = 10
  val MaxActiveGrantsPerGrantor: Int = 50
  val DefaultInviteExpiryDays: Int   = 7
  val MaxInviteExpiryDays: Int       = 30
  val MaxRangeDays: Long             = 62

  /**
   * Rendered when a counterparty person/company row no longer exists (list screens must not 500).
   */
  val DeletedPlaceholder: String = "(deleted)"

object CalendarShareService:

  val layer: ZLayer[
    CalendarShareInviteRepository & CalendarShareGrantRepository & PersonRepository & CompanyRepository & ScheduleDayRepository & DriverUnavailabilityRepository & DriverBusySlots & RateLimiter,
    Nothing,
    CalendarShareService
  ] = ZLayer.fromFunction(CalendarShareServiceImpl.apply)
