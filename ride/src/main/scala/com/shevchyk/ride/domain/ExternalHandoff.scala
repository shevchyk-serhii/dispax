package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import java.time.Instant
import zio.json.*

/**
 * A partner (external) transport company to which a ride can be handed off. Per-tenant: always scoped to a single
 * `taxiCompanyId`. Used to record which external firm will serve the ride and whom to invoice.
 */
final case class PartnerCompany(
    id: PartnerCompanyId,
    name: String,
    email: Option[String] = None,
    phone: Option[String] = None,
    address: Option[String] = None,
    taxiCompanyId: CompanyId,
    createdAt: Instant,
    updatedAt: Instant
) derives JsonCodec

/**
 * An external driver employed by a partner company (or freelance). Per-tenant. Reusable across rides: once created, a
 * dispatcher selects them from the directory instead of entering details every time.
 */
final case class ExternalDriver(
    id: ExternalDriverId,
    name: String,
    phone: Option[String] = None,
    partnerCompanyId: Option[PartnerCompanyId] = None,
    taxiCompanyId: CompanyId,
    createdAt: Instant,
    updatedAt: Instant
) derives JsonCodec

final case class CreatePartnerCompanyRequest(
    name: String,
    email: Option[String] = None,
    phone: Option[String] = None,
    address: Option[String] = None
) derives JsonCodec

final case class CreateExternalDriverRequest(
    name: String,
    phone: Option[String] = None,
    partnerCompanyId: Option[PartnerCompanyId] = None
) derives JsonCodec
