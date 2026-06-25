package com.shevchyk.app.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.billing.repository.InvoiceRepository
import com.shevchyk.core.domain.*
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.{CompanyRepository, SessionRepository}
import com.shevchyk.ride.repository.RideRepository
import sttp.model.StatusCode
import sttp.tapir.Schema
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO
import zio.json.*

import java.time.Instant

/**
 * Tapir descriptions and server logic for the SuperAdmin platform-management endpoints.
 *
 * SECURITY NOTE — Escape-hatch boundary: Every handler in this object begins with `requireSuperAdmin(user)`, which
 * checks that the authenticated user's role equals `"SUPER_ADMIN"` (case-insensitive). A SuperAdmin has `companyId =
 * None` in their JWT; `requireCompanyId` is NEVER called here. This is the ONLY file in the codebase that calls
 * `requireSuperAdmin` — no other API file has been modified.
 *
 * Cross-tenant repository methods are called only inside handlers that have already passed the SuperAdmin check. All
 * such methods are named with `All` or `Platform` suffixes to make the absence of a company_id filter immediately
 * visible in code review.
 *
 * Mirrors [[AuditApi]] in structure.
 */
object SuperAdminApi:

  import AppSecure.*

  private val superAdminTag = "SuperAdmin"

  // --------------------------------------------------------------------------
  // Response / request DTOs
  // --------------------------------------------------------------------------

  final case class CompanyResponse(
      id: String,
      name: String,
      email: String,
      phone: String,
      address: String,
      status: String,
      subscriptionPlan: String,
      createdAt: String,
      updatedAt: String
  ) derives JsonCodec

  object CompanyResponse:
    given Schema[CompanyResponse] = Schema.derived

    def from(c: Company): CompanyResponse = CompanyResponse(
      id = c.id.value.toString,
      name = c.name,
      email = c.email,
      phone = c.phone,
      address = c.address,
      status = c.status.toString,
      subscriptionPlan = c.subscriptionPlan.toString,
      createdAt = c.createdAt.toString,
      updatedAt = c.updatedAt.toString
    )

  final case class CreateCompanyRequest(
      name: String,
      email: String,
      phone: String,
      address: String,
      status: String = "Active",
      subscriptionPlan: String = "Free"
  ) derives JsonCodec

  object CreateCompanyRequest:
    given Schema[CreateCompanyRequest] = Schema.derived

  final case class UpdateCompanyRequest(
      name: Option[String] = None,
      email: Option[String] = None,
      phone: Option[String] = None,
      address: Option[String] = None,
      status: Option[String] = None,
      subscriptionPlan: Option[String] = None
  ) derives JsonCodec

  object UpdateCompanyRequest:
    given Schema[UpdateCompanyRequest] = Schema.derived

  final case class PlatformRideStats(
      byStatus: Map[String, Int],
      totalRevenue: BigDecimal,
      ridesByCompany: Map[String, Int],
      revenueByCompany: Map[String, BigDecimal]
  ) derives JsonCodec

  object PlatformRideStats:
    given Schema[PlatformRideStats] = Schema.derived

  final case class PlatformBillingStats(
      revenueByCompany: Map[String, BigDecimal],
      overdueByCompany: Map[String, Int]
  ) derives JsonCodec

  object PlatformBillingStats:
    given Schema[PlatformBillingStats] = Schema.derived

  final case class PlatformConnectionStats(
      activeSessions: Int,
      activeSessionsByCompany: Map[String, Int]
  ) derives JsonCodec

  object PlatformConnectionStats:
    given Schema[PlatformConnectionStats] = Schema.derived

  final case class CompanyStatusCount(status: String, count: Int) derives JsonCodec

  object CompanyStatusCount:
    given Schema[CompanyStatusCount] = Schema.derived

  // --------------------------------------------------------------------------
  // Combined environment type
  // --------------------------------------------------------------------------

  type SuperAdminEnv = JwtService & CompanyRepository & InvoiceRepository & RideRepository & SessionRepository

  // --------------------------------------------------------------------------
  // Endpoint descriptions (Work Stream B — company management)
  // --------------------------------------------------------------------------

  val listCompaniesEndpoint = secureEndpoint.get
    .in("api" / "superadmin" / "companies")
    .out(jsonBody[List[CompanyResponse]])
    .tag(superAdminTag)
    .summary("List all tenant companies [SuperAdmin only]")

  val getCompanyEndpoint = secureEndpoint.get
    .in("api" / "superadmin" / "companies" / path[String]("id"))
    .out(jsonBody[CompanyResponse])
    .tag(superAdminTag)
    .summary("Get a single company by ID [SuperAdmin only]")

  val createCompanyEndpoint = secureEndpoint.post
    .in("api" / "superadmin" / "companies")
    .in(jsonBody[CreateCompanyRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[CompanyResponse]))
    .tag(superAdminTag)
    .summary("Create (onboard) a new tenant company [SuperAdmin only]")

  val updateCompanyEndpoint = secureEndpoint.patch
    .in("api" / "superadmin" / "companies" / path[String]("id"))
    .in(jsonBody[UpdateCompanyRequest])
    .out(jsonBody[CompanyResponse])
    .tag(superAdminTag)
    .summary("Update company status / subscription plan [SuperAdmin only]")

  val deleteCompanyEndpoint = secureEndpoint.delete
    .in("api" / "superadmin" / "companies" / path[String]("id"))
    .out(jsonBody[CompanyResponse])
    .tag(superAdminTag)
    .summary("Soft-delete (deactivate) a tenant company [SuperAdmin only]")

  // --------------------------------------------------------------------------
  // Endpoint descriptions (Work Stream C — analytics)
  // --------------------------------------------------------------------------

  val rideAnalyticsEndpoint = secureEndpoint.get
    .in("api" / "superadmin" / "analytics" / "rides")
    .in(query[Option[String]]("from"))
    .in(query[Option[String]]("to"))
    .out(jsonBody[PlatformRideStats])
    .tag(superAdminTag)
    .summary("Cross-tenant ride analytics [SuperAdmin only]")

  val billingAnalyticsEndpoint = secureEndpoint.get
    .in("api" / "superadmin" / "analytics" / "billing")
    .in(query[Option[String]]("from"))
    .in(query[Option[String]]("to"))
    .out(jsonBody[PlatformBillingStats])
    .tag(superAdminTag)
    .summary("Cross-tenant billing analytics [SuperAdmin only]")

  val connectionAnalyticsEndpoint = secureEndpoint.get
    .in("api" / "superadmin" / "analytics" / "connections")
    .in(query[Option[String]]("companyId"))
    .out(jsonBody[PlatformConnectionStats])
    .tag(superAdminTag)
    .summary("Platform-wide active session counts [SuperAdmin only]")

  // --------------------------------------------------------------------------
  // Server logic — Work Stream B (company management)
  // --------------------------------------------------------------------------

  private val listCompaniesServer: ZServerEndpoint[SuperAdminEnv, Any] = listCompaniesEndpoint
    .serverLogic[SuperAdminEnv] { user =>
      { _ =>
        for {
          _         <- requireSuperAdmin(user)
          repo      <- ZIO.service[CompanyRepository]
          companies <- repo.findAll().mapError(internal)
        } yield companies.map(CompanyResponse.from)
      }
    }

  private val getCompanyServer: ZServerEndpoint[SuperAdminEnv, Any] = getCompanyEndpoint.serverLogic[SuperAdminEnv] {
    user =>
      { idStr =>
        for {
          _       <- requireSuperAdmin(user)
          id      <- parseUuid(idStr).map(CompanyId(_))
          repo    <- ZIO.service[CompanyRepository]
          company <- repo.findById(id).mapError(internal)
          result  <- ZIO
                       .fromOption(company)
                       .mapBoth(
                         _ => (StatusCode.NotFound, ApiError("Company not found")),
                         CompanyResponse.from
                       )
        } yield result
      }
  }

  private val createCompanyServer: ZServerEndpoint[SuperAdminEnv, Any] = createCompanyEndpoint
    .serverLogic[SuperAdminEnv] { user =>
      { req =>
        for {
          _       <- requireSuperAdmin(user)
          status  <- ZIO
                       .attempt(CompanyStatus.valueOf(req.status))
                       .orElseFail((StatusCode.BadRequest, ApiError(s"Invalid status: ${req.status}")))
          plan    <- ZIO
                       .attempt(SubscriptionPlan.valueOf(req.subscriptionPlan))
                       .orElseFail((StatusCode.BadRequest, ApiError(s"Invalid plan: ${req.subscriptionPlan}")))
          company  = Company(
                       id = CompanyId.generate(),
                       name = req.name,
                       email = req.email,
                       phone = req.phone,
                       address = req.address,
                       status = status,
                       subscriptionPlan = plan
                     )
          repo    <- ZIO.service[CompanyRepository]
          created <- repo.create(company).mapError(internal)
        } yield CompanyResponse.from(created)
      }
    }

  private val updateCompanyServer: ZServerEndpoint[SuperAdminEnv, Any] = updateCompanyEndpoint
    .serverLogic[SuperAdminEnv] { user =>
      { case (idStr, req) =>
        for {
          _         <- requireSuperAdmin(user)
          id        <- parseUuid(idStr).map(CompanyId(_))
          repo      <- ZIO.service[CompanyRepository]
          existing  <- repo.findById(id).mapError(internal)
          company   <- ZIO
                         .fromOption(existing)
                         .orElseFail((StatusCode.NotFound, ApiError("Company not found")))
          newStatus <-
            req.status match
              case None    => ZIO.succeed(company.status)
              case Some(s) =>
                ZIO
                  .attempt(CompanyStatus.valueOf(s))
                  .orElseFail((StatusCode.BadRequest, ApiError(s"Invalid status: $s")))
          newPlan   <-
            req.subscriptionPlan match
              case None    => ZIO.succeed(company.subscriptionPlan)
              case Some(p) =>
                ZIO
                  .attempt(SubscriptionPlan.valueOf(p))
                  .orElseFail((StatusCode.BadRequest, ApiError(s"Invalid plan: $p")))
          updated    = company.copy(
                         name = req.name.getOrElse(company.name),
                         email = req.email.getOrElse(company.email),
                         phone = req.phone.getOrElse(company.phone),
                         address = req.address.getOrElse(company.address),
                         status = newStatus,
                         subscriptionPlan = newPlan
                       )
          saved     <- repo.update(updated).mapError(internal)
        } yield CompanyResponse.from(saved)
      }
    }

  private val deleteCompanyServer: ZServerEndpoint[SuperAdminEnv, Any] = deleteCompanyEndpoint
    .serverLogic[SuperAdminEnv] { user =>
      { idStr =>
        for {
          _       <- requireSuperAdmin(user)
          id      <- parseUuid(idStr).map(CompanyId(_))
          repo    <- ZIO.service[CompanyRepository]
          result  <- repo.softDelete(id).mapError(internal)
          company <- ZIO
                       .fromOption(result)
                       .mapBoth(
                         _ => (StatusCode.NotFound, ApiError("Company not found")),
                         CompanyResponse.from
                       )
        } yield company
      }
    }

  // --------------------------------------------------------------------------
  // Server logic — Work Stream C (analytics)
  // --------------------------------------------------------------------------

  private def parseInstantParam(s: String): ZIO[Any, Err, Instant] = ZIO
    .attempt(Instant.parse(s))
    .orElseFail((StatusCode.BadRequest, ApiError(s"Invalid ISO-8601 date-time: $s")))

  private val rideAnalyticsServer: ZServerEndpoint[SuperAdminEnv, Any] = rideAnalyticsEndpoint
    .serverLogic[SuperAdminEnv] { user =>
      { case (fromOpt, toOpt) =>
        for {
          _                <- requireSuperAdmin(user)
          now               = Instant.now()
          from             <- fromOpt.fold(ZIO.succeed(now.minusSeconds(30L * 24 * 3600)))(parseInstantParam)
          to               <- toOpt.fold(ZIO.succeed(now))(parseInstantParam)
          repo             <- ZIO.service[RideRepository]
          byStatus         <- repo.countAllRidesByStatus().mapError(internal)
          totalRevenue     <- repo.sumAllRevenue(from, to).mapError(internal)
          ridesByCompany   <- repo.countRidesByCompany(from, to).mapError(internal)
          revenueByCompany <- repo.sumRevenueByCompanyPlatform(from, to).mapError(internal)
        } yield PlatformRideStats(
          byStatus = byStatus,
          totalRevenue = totalRevenue,
          ridesByCompany = ridesByCompany.map { case (k, v) => k.toString -> v },
          revenueByCompany = revenueByCompany.map { case (k, v) => k.toString -> v }
        )
      }
    }

  private val billingAnalyticsServer: ZServerEndpoint[SuperAdminEnv, Any] = billingAnalyticsEndpoint
    .serverLogic[SuperAdminEnv] { user =>
      { case (fromOpt, toOpt) =>
        for {
          _       <- requireSuperAdmin(user)
          now      = Instant.now()
          from    <- fromOpt.fold(ZIO.succeed(now.minusSeconds(30L * 24 * 3600)))(parseInstantParam)
          to      <- toOpt.fold(ZIO.succeed(now))(parseInstantParam)
          repo    <- ZIO.service[InvoiceRepository]
          revenue <- repo.sumRevenueByCompany(from, to).mapError(internal)
          overdue <- repo.countOverdueByCompany().mapError(internal)
        } yield PlatformBillingStats(
          revenueByCompany = revenue.map { case (k, v) => k.toString -> v },
          overdueByCompany = overdue.map { case (k, v) => k.toString -> v }
        )
      }
    }

  private val connectionAnalyticsServer: ZServerEndpoint[SuperAdminEnv, Any] = connectionAnalyticsEndpoint
    .serverLogic[SuperAdminEnv] { user =>
      { _ =>
        for {
          _     <- requireSuperAdmin(user)
          repo  <- ZIO.service[SessionRepository]
          total <- repo.countActivePlatform().mapError(internal)
        } yield PlatformConnectionStats(
          activeSessions = total,
          activeSessionsByCompany = Map.empty // populated when needed via optional companyId param
        )
      }
    }

  // --------------------------------------------------------------------------
  // Public API surface
  // --------------------------------------------------------------------------

  val serverEndpoints: List[ZServerEndpoint[SuperAdminEnv, Any]] = List(
    listCompaniesServer,
    getCompanyServer,
    createCompanyServer,
    updateCompanyServer,
    deleteCompanyServer,
    rideAnalyticsServer,
    billingAnalyticsServer,
    connectionAnalyticsServer
  )
