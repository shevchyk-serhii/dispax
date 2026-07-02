package com.shevchyk.app.openapi

import com.shevchyk.core.domain.PersonId
import com.shevchyk.core.repository.PersonRepository
import zio.ZIO

/**
 * Bulk display-name resolution for person ids, used to enrich list responses with human-readable names instead of bare
 * UUIDs (same pattern as the client-name lookup in `RideApi`). Ids that resolve to no person are simply absent from the
 * resulting map.
 */
object PersonNameLookup:

  def names(ids: Seq[PersonId]): ZIO[PersonRepository, Throwable, Map[PersonId, String]] =
    for
      repo    <- ZIO.service[PersonRepository]
      persons <- ZIO.foreachPar(ids.distinct)(id => repo.findById(id).map(p => id -> p))
    yield persons.collect { case (id, Some(p)) => id -> p.name }.toMap
