package com.shevchyk.core.repository

import com.shevchyk.core.domain.{Company, CompanyId, CompanyStatus, SubscriptionPlan}
import doobie.*
import doobie.implicits.*
import doobie.postgres.*
import doobie.postgres.implicits.*
import zio.*
import zio.interop.catz.*

import java.time.{Instant, OffsetDateTime, ZoneOffset}
import java.util.UUID

final class PostgresCompanyRepository(xa: Transactor[Task]) extends CompanyRepository:

  // -- Doobie Meta mappings --------------------------------------------------

  implicit val instantMeta: Meta[Instant] =
    Meta[OffsetDateTime].imap(_.toInstant)(i => OffsetDateTime.ofInstant(i, ZoneOffset.UTC))

  /**
   * Map the `company_status` PostgreSQL enum to [[CompanyStatus]].
   */
  implicit val companyStatusMeta: Meta[CompanyStatus] = pgEnumString(
    "company_status",
    {
      case "Active"    => CompanyStatus.Active
      case "Suspended" => CompanyStatus.Suspended
      case "Trial"     => CompanyStatus.Trial
      case "Inactive"  => CompanyStatus.Inactive
    },
    {
      case CompanyStatus.Active    => "Active"
      case CompanyStatus.Suspended => "Suspended"
      case CompanyStatus.Trial     => "Trial"
      case CompanyStatus.Inactive  => "Inactive"
    }
  )

  /**
   * Map the `subscription_plan` PostgreSQL enum to [[SubscriptionPlan]].
   */
  implicit val subscriptionPlanMeta: Meta[SubscriptionPlan] = pgEnumString(
    "subscription_plan",
    {
      case "Free"         => SubscriptionPlan.Free
      case "Starter"      => SubscriptionPlan.Starter
      case "Professional" => SubscriptionPlan.Professional
      case "Enterprise"   => SubscriptionPlan.Enterprise
    },
    {
      case SubscriptionPlan.Free         => "Free"
      case SubscriptionPlan.Starter      => "Starter"
      case SubscriptionPlan.Professional => "Professional"
      case SubscriptionPlan.Enterprise   => "Enterprise"
    }
  )

  /**
   * Read a company row from the DB result set.
   */
  implicit val companyRead: Read[Company] =
    Read[
      (UUID, String, String, String, String, CompanyStatus, SubscriptionPlan, Instant, Instant)
    ].map { case (id, name, email, phone, address, status, plan, createdAt, updatedAt) =>
      Company(
        id = CompanyId(id),
        name = name,
        email = email,
        phone = phone,
        address = address,
        status = status,
        subscriptionPlan = plan,
        createdAt = createdAt,
        updatedAt = updatedAt
      )
    }

  private val selectColumns: Fragment =
    fr"id, name, email, phone, address, status, subscription_plan, created_at, updated_at"

  // -- Trait implementation --------------------------------------------------

  override def findAll(): Task[List[Company]] = (fr"SELECT" ++ selectColumns ++ fr"FROM companies ORDER BY name")
    .query[Company]
    .to[List]
    .transact(xa)

  override def findById(id: CompanyId): Task[Option[Company]] =
    (fr"SELECT" ++ selectColumns ++ fr"FROM companies WHERE id = ${id.value}")
      .query[Company]
      .option
      .transact(xa)

  override def create(company: Company): Task[Company] =
    (fr"""
      INSERT INTO companies (id, name, email, phone, address, status, subscription_plan)
      VALUES (
        ${company.id.value},
        ${company.name},
        ${company.email},
        ${company.phone},
        ${company.address},
        ${company.status},
        ${company.subscriptionPlan}
      )
      RETURNING""" ++ selectColumns)
      .query[Company]
      .unique
      .transact(xa)

  override def update(company: Company): Task[Company] =
    sql"""
      UPDATE companies
      SET name              = ${company.name},
          email             = ${company.email},
          phone             = ${company.phone},
          address           = ${company.address},
          status            = ${company.status},
          subscription_plan = ${company.subscriptionPlan},
          updated_at        = NOW()
      WHERE id = ${company.id.value}
    """.update.run
      .transact(xa)
      .as(company)

  override def countByStatus(): Task[Map[CompanyStatus, Int]] =
    sql"""
      SELECT status, COUNT(*)::int
      FROM companies
      GROUP BY status
    """
      .query[(CompanyStatus, Int)]
      .to[List]
      .transact(xa)
      .map(_.toMap)
