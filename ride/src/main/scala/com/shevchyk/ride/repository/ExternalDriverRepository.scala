package com.shevchyk.ride.repository

import com.shevchyk.core.domain.{CompanyId, ExternalDriverId}
import com.shevchyk.ride.domain.ExternalDriver
import zio.*

trait ExternalDriverRepository:
  def create(ed: ExternalDriver): Task[ExternalDriver]

  /**
   * Finds an external driver by id, but only within the given tenant. Returns None for cross-tenant lookups.
   */
  def findById(id: ExternalDriverId, companyId: CompanyId): Task[Option[ExternalDriver]]

  def findByCompany(companyId: CompanyId): Task[List[ExternalDriver]]
