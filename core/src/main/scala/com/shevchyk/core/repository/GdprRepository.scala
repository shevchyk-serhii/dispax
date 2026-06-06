package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.*
import java.time.Instant
import java.util.UUID

trait GdprRepository:
  def createConsent(consent: GdprConsent): Task[GdprConsent]
  def findConsentsByUserId(userId: PersonId): Task[List[GdprConsent]]
  def revokeConsent(userId: PersonId, consentType: ConsentType): Task[Boolean]
  def createRequest(request: GdprRequest): Task[GdprRequest]
  def findRequestsByUserId(userId: PersonId): Task[List[GdprRequest]]
  def findAllRequests(): Task[List[GdprRequest]]
  def updateRequestStatus(requestId: GdprRequestId, status: GdprRequestStatus): Task[Boolean]

object GdprRepository:

  val inMemory: ZLayer[Any, Nothing, GdprRepository] = ZLayer.succeed(InMemoryGdprRepository())

  val layer: ZLayer[Any, Throwable, GdprRepository] =
    com.shevchyk.core.database.DatabaseConfig.liveTransactorWithMigrations >>> PostgresGdprRepository.postgresLayer

class InMemoryGdprRepository extends GdprRepository:
  private var consents: List[GdprConsent] = List.empty
  private var requests: List[GdprRequest] = List.empty

  override def createConsent(consent: GdprConsent): Task[GdprConsent] = ZIO.succeed {
    consents = consents.filterNot(c => c.userId == consent.userId && c.consentType == consent.consentType) :+ consent
    consent
  }

  override def findConsentsByUserId(userId: PersonId): Task[List[GdprConsent]] = ZIO.succeed {
    consents.filter(_.userId == userId)
  }

  override def revokeConsent(userId: PersonId, consentType: ConsentType): Task[Boolean] = ZIO.succeed {
    val idx = consents.indexWhere(c => c.userId == userId && c.consentType == consentType && c.revokedAt.isEmpty)
    if idx >= 0 then
      consents = consents.updated(idx, consents(idx).copy(revokedAt = Some(Instant.now())))
      true
    else false
  }

  override def createRequest(request: GdprRequest): Task[GdprRequest] = ZIO.succeed {
    requests = requests :+ request
    request
  }

  override def findRequestsByUserId(userId: PersonId): Task[List[GdprRequest]] = ZIO.succeed {
    requests.filter(_.userId == userId)
  }

  override def findAllRequests(): Task[List[GdprRequest]] = ZIO.succeed(requests)

  override def updateRequestStatus(requestId: GdprRequestId, status: GdprRequestStatus): Task[Boolean] = ZIO.succeed {
    val idx = requests.indexWhere(_.id == requestId)
    if idx >= 0 then
      val completedAt = if status == GdprRequestStatus.COMPLETED then Some(Instant.now()) else None
      requests = requests.updated(idx, requests(idx).copy(status = status, completedAt = completedAt))
      true
    else false
  }
