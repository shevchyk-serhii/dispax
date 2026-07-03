package com.shevchyk.app.openapi

import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.core.repository.PersonRepository
import zio.ZIO

/**
 * Bulk display-name resolution for person ids, used to enrich list responses with human-readable names instead of bare
 * UUIDs (same pattern as the client-name lookup in `RideApi`). Ids that resolve to no person are simply absent from the
 * resulting map.
 *
 * Resolution is a SINGLE company-scoped query (`findByCompanyId`), not one lookup per id: the previous implementation
 * ran an unbounded `ZIO.foreachPar` of `findById` — N concurrent SQL queries against a 10-connection pool, and each
 * `findById` was tenant-unscoped. With the company filter an id from another company resolves to no name (tenant
 * isolation by construction).
 */
object PersonNameLookup:

  def names(ids: Seq[PersonId], companyId: CompanyId): ZIO[PersonRepository, Throwable, Map[PersonId, String]] =
    if ids.isEmpty then ZIO.succeed(Map.empty)
    else
      for
        repo    <- ZIO.service[PersonRepository]
        persons <- repo.findByCompanyId(companyId)
      yield
        val wanted = ids.toSet
        persons.collect { case p if wanted.contains(p.id) => p.id -> p.name }.toMap
