package com.shevchyk.core.repository

import com.shevchyk.core.domain.*
import zio.test.*
import zio.*
import java.time.Instant

object GdprRepositorySpec extends ZIOSpecDefault {

  val userId1 = PersonId.generate()
  val userId2 = PersonId.generate()

  def makeConsent(
      userId: PersonId = userId1,
      consentType: ConsentType = ConsentType.DataProcessing
  ): GdprConsent = GdprConsent(
    id = GdprConsentId.generate(),
    userId = userId,
    consentType = consentType,
    grantedAt = Instant.now()
  )

  def makeRequest(
      userId: PersonId = userId1,
      requestType: GdprRequestType = GdprRequestType.EXPORT
  ): GdprRequest = GdprRequest(
    id = GdprRequestId.generate(),
    userId = userId,
    requestType = requestType,
    status = GdprRequestStatus.PENDING,
    requestedAt = Instant.now()
  )

  val layers = GdprRepository.inMemory

  def spec = suite("GdprRepository")(
    suite("createConsent and findConsentsByUserId")(
      test("creates and finds consent") {
        val consent = makeConsent()
        for {
          repo  <- ZIO.service[GdprRepository]
          _     <- repo.createConsent(consent)
          found <- repo.findConsentsByUserId(userId1)
        } yield assertTrue(found.size == 1 && found.head.consentType == ConsentType.DataProcessing)
      }.provide(layers),
      test("returns empty for unknown user") {
        for {
          repo  <- ZIO.service[GdprRepository]
          _     <- repo.createConsent(makeConsent(userId = userId1))
          found <- repo.findConsentsByUserId(userId2)
        } yield assertTrue(found.isEmpty)
      }.provide(layers),
      test("creating same consent type replaces previous one") {
        val c1 = makeConsent(userId = userId1, consentType = ConsentType.Marketing)
        val c2 = makeConsent(userId = userId1, consentType = ConsentType.Marketing)
        for {
          repo  <- ZIO.service[GdprRepository]
          _     <- repo.createConsent(c1)
          _     <- repo.createConsent(c2)
          found <- repo.findConsentsByUserId(userId1)
          marketing = found.filter(_.consentType == ConsentType.Marketing)
        } yield assertTrue(marketing.size == 1 && marketing.head.id == c2.id)
      }.provide(layers),
      test("can have multiple different consent types") {
        for {
          repo  <- ZIO.service[GdprRepository]
          _     <- repo.createConsent(makeConsent(consentType = ConsentType.DataProcessing))
          _     <- repo.createConsent(makeConsent(consentType = ConsentType.Marketing))
          _     <- repo.createConsent(makeConsent(consentType = ConsentType.Analytics))
          found <- repo.findConsentsByUserId(userId1)
        } yield assertTrue(found.size == 3)
      }.provide(layers)
    ),
    suite("revokeConsent")(
      test("revokes active consent and sets revokedAt") {
        val consent = makeConsent()
        for {
          repo    <- ZIO.service[GdprRepository]
          _       <- repo.createConsent(consent)
          result  <- repo.revokeConsent(userId1, ConsentType.DataProcessing)
          found   <- repo.findConsentsByUserId(userId1)
        } yield assertTrue(result && found.head.revokedAt.isDefined)
      }.provide(layers),
      test("returns false for non-existent consent") {
        for {
          repo   <- ZIO.service[GdprRepository]
          result <- repo.revokeConsent(userId1, ConsentType.Marketing)
        } yield assertTrue(!result)
      }.provide(layers),
      test("returns false if already revoked") {
        val consent = makeConsent()
        for {
          repo    <- ZIO.service[GdprRepository]
          _       <- repo.createConsent(consent)
          _       <- repo.revokeConsent(userId1, ConsentType.DataProcessing)
          result2 <- repo.revokeConsent(userId1, ConsentType.DataProcessing)
        } yield assertTrue(!result2)
      }.provide(layers)
    ),
    suite("createRequest and findRequestsByUserId")(
      test("creates and finds request") {
        val request = makeRequest()
        for {
          repo  <- ZIO.service[GdprRepository]
          _     <- repo.createRequest(request)
          found <- repo.findRequestsByUserId(userId1)
        } yield assertTrue(found.size == 1 && found.head.requestType == GdprRequestType.EXPORT)
      }.provide(layers),
      test("returns empty for unknown user") {
        for {
          repo  <- ZIO.service[GdprRepository]
          _     <- repo.createRequest(makeRequest(userId = userId1))
          found <- repo.findRequestsByUserId(userId2)
        } yield assertTrue(found.isEmpty)
      }.provide(layers),
      test("multiple requests are all stored") {
        for {
          repo  <- ZIO.service[GdprRepository]
          _     <- repo.createRequest(makeRequest(requestType = GdprRequestType.EXPORT))
          _     <- repo.createRequest(makeRequest(requestType = GdprRequestType.DELETION))
          found <- repo.findRequestsByUserId(userId1)
        } yield assertTrue(found.size == 2)
      }.provide(layers)
    ),
    suite("updateRequestStatus")(
      test("updates status to PROCESSING") {
        val request = makeRequest()
        for {
          repo   <- ZIO.service[GdprRepository]
          _      <- repo.createRequest(request)
          result <- repo.updateRequestStatus(request.id, GdprRequestStatus.PROCESSING)
          found  <- repo.findRequestsByUserId(userId1)
        } yield assertTrue(result && found.head.status == GdprRequestStatus.PROCESSING)
      }.provide(layers),
      test("sets completedAt when status is COMPLETED") {
        val request = makeRequest()
        for {
          repo   <- ZIO.service[GdprRepository]
          _      <- repo.createRequest(request)
          _      <- repo.updateRequestStatus(request.id, GdprRequestStatus.COMPLETED)
          found  <- repo.findRequestsByUserId(userId1)
        } yield assertTrue(found.head.completedAt.isDefined)
      }.provide(layers),
      test("does not set completedAt for REJECTED status") {
        val request = makeRequest()
        for {
          repo  <- ZIO.service[GdprRepository]
          _     <- repo.createRequest(request)
          _     <- repo.updateRequestStatus(request.id, GdprRequestStatus.REJECTED)
          found <- repo.findRequestsByUserId(userId1)
        } yield assertTrue(found.head.completedAt.isEmpty)
      }.provide(layers),
      test("returns false for unknown request id") {
        for {
          repo   <- ZIO.service[GdprRepository]
          result <- repo.updateRequestStatus(GdprRequestId.generate(), GdprRequestStatus.COMPLETED)
        } yield assertTrue(!result)
      }.provide(layers)
    )
  )
}
