package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{CompanyId, PartnerCompanyId}
import com.shevchyk.ride.domain.PartnerCompany
import zio.*

trait PartnerCompanyRepository:
  def create(pc: PartnerCompany): Task[PartnerCompany]

  /**
   * Finds a partner company by id, but only within the given tenant. Returns None for cross-tenant lookups.
   */
  def findById(id: PartnerCompanyId, companyId: CompanyId): Task[Option[PartnerCompany]]

  def findByCompany(companyId: CompanyId): Task[List[PartnerCompany]]
