package com.shevchyk.schedule.domain

import com.shevchyk.core.domain.{CalendarShareGrantId, CalendarShareInviteId, CompanyId, PersonId}
import com.shevchyk.core.openapi.{ApiError, ErrorMapper}
import sttp.model.StatusCode

import java.security.SecureRandom
import java.time.Instant
import java.util.Base64

/**
 * An invitation to view the grantor's personal calendar. The token is high-entropy and non-enumerable (NOT a UUID);
 * whoever redeems it while logged in becomes a grantee. Multi-use until `expiresAt` or explicit revocation: a grantor
 * typically hands one code to a partner firm where several dispatchers redeem it, and each resulting grant stays
 * individually revocable.
 */
final case class CalendarShareInvite(
    id: CalendarShareInviteId,
    token: String,
    grantorPersonId: PersonId,
    grantorCompanyId: CompanyId,
    createdAt: Instant,
    expiresAt: Instant,
    revokedAt: Option[Instant]
):
  def isActive(now: Instant): Boolean = revokedAt.isEmpty && now.isBefore(expiresAt)

object CalendarShareInvite:

  private val secureRandom = new SecureRandom()

  /**
   * Same recipe as `RideShareToken.generateTokenValue()` (ride module — not importable from here without breaking the
   * sibling-module boundary): 32 random bytes → URL-safe unpadded Base64, ~256 bits of entropy, ~43 chars.
   */
  def generateTokenValue(): String =
    val bytes = new Array[Byte](32)
    secureRandom.nextBytes(bytes)
    Base64.getUrlEncoder.withoutPadding().encodeToString(bytes)

  /**
   * Cheap syntactic pre-check so garbage input never reaches the database. Accepts the exact charset/length range the
   * generator can produce (plus some slack for future longer tokens).
   */
  def isPlausibleToken(raw: String): Boolean =
    raw.length >= 20 && raw.length <= 64 && raw.forall(c =>
      (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_'
    )

/**
 * A persistent, individually revocable permission: `granteePersonId` may read the PII-free personal calendar of
 * `grantorPersonId`. Both company ids are denormalized at redeem time. Soft-revoked via `revokedAt` so history
 * survives; `expiresAt` is reserved for future time-boxed grants (always None in v1).
 */
final case class CalendarShareGrant(
    id: CalendarShareGrantId,
    inviteId: Option[CalendarShareInviteId],
    grantorPersonId: PersonId,
    grantorCompanyId: CompanyId,
    granteePersonId: PersonId,
    granteeCompanyId: CompanyId,
    createdAt: Instant,
    expiresAt: Option[Instant],
    revokedAt: Option[Instant]
):
  def isActive(now: Instant): Boolean = revokedAt.isEmpty && expiresAt.forall(now.isBefore)

enum CalendarShareError extends Throwable:
  case ValidationError(message: String)
  case SelfShareNotAllowed
  // Unknown, expired and revoked invites all collapse to one 404 so token probing learns nothing.
  case InviteInvalid
  case InviteNotFound(id: CalendarShareInviteId)
  // Foreign, unknown, revoked and expired grants all collapse to one 404 (never 403 — no existence leak).
  case GrantNotFound(id: CalendarShareGrantId)
  case TooManyActiveInvites
  case TooManyActiveGrants
  case RateLimited
  case DatabaseError(cause: Throwable)

object CalendarShareError:

  given ErrorMapper[CalendarShareError] = ErrorMapper.instance {
    case ValidationError(message) => (StatusCode.BadRequest, ApiError(message))
    case SelfShareNotAllowed      => (StatusCode.BadRequest, ApiError("You cannot share a calendar with yourself"))
    case InviteInvalid            => (StatusCode.NotFound, ApiError("Invite code not found or expired"))
    case InviteNotFound(id)       => (StatusCode.NotFound, ApiError(s"Invite not found: ${id.value}"))
    case GrantNotFound(id)        => (StatusCode.NotFound, ApiError(s"Calendar share not found: ${id.value}"))
    case TooManyActiveInvites     => (StatusCode.Conflict, ApiError("Too many active invites — revoke one first"))
    case TooManyActiveGrants      => (StatusCode.Conflict, ApiError("Too many active calendar shares for this user"))
    case RateLimited              => (StatusCode.TooManyRequests, ApiError("Too many attempts — try again later"))
    case DatabaseError(_)         => (StatusCode.InternalServerError, ApiError("Internal server error"))
  }
