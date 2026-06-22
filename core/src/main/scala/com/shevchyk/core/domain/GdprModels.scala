package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class GdprConsentId(value: UUID)

object GdprConsentId:
  def generate(): GdprConsentId  = GdprConsentId(UuidCreator.getTimeOrderedEpoch())
  given JsonCodec[GdprConsentId] = JsonCodec[UUID].transform(GdprConsentId(_), _.value)

enum ConsentType derives JsonCodec:
  case DataProcessing, Marketing, Analytics, ThirdPartySharing

case class GdprConsent(
    id: GdprConsentId,
    userId: PersonId,
    consentType: ConsentType,
    grantedAt: Instant,
    revokedAt: Option[Instant] = None,
    ipAddress: Option[String] = None
) derives JsonCodec

case class GdprRequestId(value: UUID)

object GdprRequestId:
  def generate(): GdprRequestId  = GdprRequestId(UuidCreator.getTimeOrderedEpoch())
  given JsonCodec[GdprRequestId] = JsonCodec[UUID].transform(GdprRequestId(_), _.value)

enum GdprRequestType derives JsonCodec:
  case EXPORT, DELETION

enum GdprRequestStatus derives JsonCodec:
  case PENDING, PROCESSING, COMPLETED, REJECTED

case class GdprRequest(
    id: GdprRequestId,
    userId: PersonId,
    requestType: GdprRequestType,
    status: GdprRequestStatus = GdprRequestStatus.PENDING,
    requestedAt: Instant,
    completedAt: Option[Instant] = None,
    notes: Option[String] = None
) derives JsonCodec

case class UpdateConsentRequest(
    consentType: String,
    granted: Boolean
) derives JsonCodec

case class GdprDataExport(
    user: Map[String, String],
    rides: List[Map[String, String]],
    expenses: List[Map[String, String]],
    consents: List[GdprConsent],
    exportedAt: Instant
) derives JsonCodec
