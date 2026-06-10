package com.shevchyk.billing.infrastructure

import com.shevchyk.auth.config.JwtConfig
import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.domain.*
import com.shevchyk.billing.infrastructure.http.BillingProfileRoutes
import com.shevchyk.billing.repository.CompanyBillingProfileRepository
import com.shevchyk.core.domain.*
import zio.*
import zio.http.*
import zio.test.*

import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

object BillingProfileRoutesSpec extends ZIOSpecDefault {

  private val testJwtConfig: ZLayer[Any, Nothing, JwtConfig]   = ZLayer.succeed(
    JwtConfig(
      secret = "test-secret-at-least-256-bits-long-for-hmac-sha256-algorithm-padding",
      issuer = "test",
      audience = "test",
      expirationTime = scala.concurrent.duration.Duration.fromNanos(3600L * 1_000_000_000L)
    )
  )
  private val testJwtService: ZLayer[Any, Nothing, JwtService] = testJwtConfig >>> JwtService.live

  private val adminId      = UUID.fromString("00000001-0000-0000-0000-000000000001")
  private val dispatcherId = UUID.fromString("00000001-0000-0000-0000-000000000002")
  private val driverId     = UUID.fromString("00000001-0000-0000-0000-000000000003")
  private val companyId    = UUID.fromString("00000003-0000-0000-0000-000000000003")

  private def token(role: PersonRole, uid: UUID): ZIO[JwtService, Throwable, String] = ZIO.serviceWithZIO[JwtService](
    _.generateToken(Person(PersonId(uid), "Test", "test@example.com", role, Some(CompanyId(companyId))))
  )

  private val inMemoryProfileRepo: ZLayer[Any, Nothing, CompanyBillingProfileRepository] = ZLayer.succeed {
    new CompanyBillingProfileRepository {
      private val store                                                                                = new ConcurrentHashMap[CompanyId, CompanyBillingProfile]()
      def findByCompany(cid: CompanyId): Task[Option[CompanyBillingProfile]]                           = ZIO.succeed(Option(store.get(cid)))
      def upsert(cid: CompanyId, req: UpdateCompanyBillingProfileRequest): Task[CompanyBillingProfile] = ZIO.succeed {
        val p = CompanyBillingProfile(
          companyId = cid,
          legalName = req.legalName,
          iban = req.iban,
          paymentTermsDays = req.paymentTermsDays.getOrElse(7)
        )
        store.put(cid, p)
        p
      }
    }
  }

  private val testLayers = inMemoryProfileRepo ++ testJwtService

  private def run(req: Request): ZIO[CompanyBillingProfileRepository & JwtService, Nothing, Response] =
    BillingProfileRoutes.authenticatedRoutes
      .run(req)
      .either
      .map {
        case Left(r)  => r.merge
        case Right(r) => r
      }

  private val profileUrl = URL.decode("/api/billing/profile").toOption.get
  private val validBody  = """{"legalName":"Dispax München","iban":"DE24","paymentTermsDays":14}"""

  def spec =
    suite("BillingProfileRoutes")(
      suite("GET /api/billing/profile")(
        test("dispatcher gets profile (200, empty default when none)") {
          for {
            tok <- token(PersonRole.Dispatcher, dispatcherId)
            res <- run(Request.get(profileUrl).addHeader(Header.Authorization.Bearer(tok)))
          } yield assertTrue(res.status == Status.Ok)
        }.provide(testLayers),
        test("admin gets profile (200)") {
          for {
            tok <- token(PersonRole.Admin, adminId)
            res <- run(Request.get(profileUrl).addHeader(Header.Authorization.Bearer(tok)))
          } yield assertTrue(res.status == Status.Ok)
        }.provide(testLayers),
        test("driver is forbidden (403)") {
          for {
            tok <- token(PersonRole.Driver, driverId)
            res <- run(Request.get(profileUrl).addHeader(Header.Authorization.Bearer(tok)))
          } yield assertTrue(res.status == Status.Forbidden)
        }.provide(testLayers),
        test("returns 401 without token") {
          run(Request.get(profileUrl)).map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(testLayers)
      ),
      suite("PUT /api/billing/profile")(
        test("dispatcher can upsert profile (200) and value round-trips") {
          for {
            tok  <- token(PersonRole.Dispatcher, dispatcherId)
            put  <- run(
                      Request
                        .put(profileUrl, Body.fromString(validBody))
                        .addHeader(Header.Authorization.Bearer(tok))
                    )
            get  <- run(Request.get(profileUrl).addHeader(Header.Authorization.Bearer(tok)))
            body <- get.body.asString
          } yield assertTrue(
            put.status == Status.Ok,
            body.contains("Dispax München"),
            body.contains("\"paymentTermsDays\":14")
          )
        }.provide(testLayers),
        test("driver is forbidden (403)") {
          for {
            tok <- token(PersonRole.Driver, driverId)
            res <- run(
                     Request
                       .put(profileUrl, Body.fromString(validBody))
                       .addHeader(Header.Authorization.Bearer(tok))
                   )
          } yield assertTrue(res.status == Status.Forbidden)
        }.provide(testLayers),
        test("returns 401 without token") {
          run(Request.put(profileUrl, Body.fromString(validBody)))
            .map(r => assertTrue(r.status == Status.Unauthorized))
        }.provide(testLayers)
      )
    )
}
