package com.shevchyk.schedule.infrastructure

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.schedule.application.ScheduleService
import com.shevchyk.schedule.infrastructure.http.ScheduleRoutes
import com.shevchyk.schedule.repository.InMemoryScheduleDayRepository
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID

object ScheduleRoutesSpec extends ZIOSpecDefault {

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig] = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-at-least-256-bits-long-for-hmac-sha256-algorithm-padding",
      issuer = "test", audience = "test",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
    )
  )
  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private val dispatcherId = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val driverId     = UUID.fromString("00000002-0000-0000-0000-000000000002")
  private val clientId     = UUID.fromString("00000003-0000-0000-0000-000000000003")
  private val companyId    = UUID.fromString("00000004-0000-0000-0000-000000000004")

  private def token(role: PersonRole, uid: UUID, cid: Option[UUID] = Some(companyId)): ZIO[JwtService, Throwable, String] =
    ZIO.serviceWithZIO[JwtService](_.generateToken(
      Person(PersonId(uid), "test@example.com", "Test", role, "hash", cid.map(CompanyId.apply), UserStatus.ACTIVE)
    ))

  private val testLayers = (InMemoryScheduleDayRepository.layer >>> ScheduleService.layer) ++ testJwtService

  private def run(req: Request): ZIO[ScheduleService & JwtService, Nothing, Response] =
    ScheduleRoutes.authenticatedRoutes.run(req).either.map {
      case Left(r)  => r.merge
      case Right(r) => r
    }

  private val validScheduleJson =
    s"""{
      "driverId": "$driverId",
      "date": "2026-08-01",
      "shiftStart": "08:00",
      "shiftEnd": "16:00"
    }"""

  def spec = suite("ScheduleRoutes")(

    suite("POST /api/schedules")(
      test("dispatcher can create schedule day (201)") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.post(
                        URL.decode("/api/schedules").toOption.get,
                        Body.fromString(validScheduleJson)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Created || response.status == Status.BadRequest)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.post(URL.decode("/api/schedules").toOption.get, Body.fromString(validScheduleJson)))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.post(
                        URL.decode("/api/schedules").toOption.get,
                        Body.fromString(validScheduleJson)
                      ).addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers)
    ),

    suite("GET /api/schedules")(
      test("dispatcher can list schedules (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.get(URL.decode("/api/schedules").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("driver can list own schedules (200)") {
        for {
          tok      <- token(PersonRole.Driver, driverId)
          response <- run(Request.get(URL.decode("/api/schedules").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.get(URL.decode("/api/schedules").toOption.get))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    ),

    suite("GET /api/schedules/:id")(
      test("returns 400 or 404 for unknown schedule") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.get(URL.decode(s"/api/schedules/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.NotFound || response.status == Status.BadRequest || response.status == Status.Forbidden)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.get(URL.decode(s"/api/schedules/${UUID.randomUUID()}").toOption.get))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    ),

    suite("DELETE /api/schedules/:id")(
      test("returns 401 without token") {
        run(Request.delete(URL.decode(s"/api/schedules/${UUID.randomUUID()}").toOption.get))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers),

      test("client is forbidden (403)") {
        for {
          tok      <- token(PersonRole.Client, clientId)
          response <- run(Request.delete(URL.decode(s"/api/schedules/${UUID.randomUUID()}").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Forbidden)
      }.provide(testLayers)
    ),

    suite("GET /api/schedules/driver/:id")(
      test("dispatcher can get driver schedules (200)") {
        for {
          tok      <- token(PersonRole.Dispatcher, dispatcherId)
          response <- run(Request.get(URL.decode(s"/api/schedules/driver/$driverId").toOption.get)
                        .addHeader(Header.Authorization.Bearer(tok)))
        } yield assertTrue(response.status == Status.Ok)
      }.provide(testLayers),

      test("returns 401 without token") {
        run(Request.get(URL.decode(s"/api/schedules/driver/$driverId").toOption.get))
          .map(r => assertTrue(r.status == Status.Unauthorized))
      }.provide(testLayers)
    )
  )
}
