package com.shevchyk.app.openapi

import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.{InMemoryPersonRepository, PersonRepository}
import zio.*
import zio.test.*

import java.util.UUID

/**
 * Unit tests for the bulk, company-scoped person-name resolution. Regression for the audit finding: the lookup used to
 * issue one tenant-UNSCOPED `findById` per id via an unbounded `foreachPar` — N+1 queries and a cross-tenant footgun.
 */
object PersonNameLookupSpec extends ZIOSpecDefault:

  private val companyA = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000aa"))
  private val companyB = CompanyId(UUID.fromString("00000001-0000-0000-0000-0000000000bb"))

  private val driverA1 = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000a1"))
  private val driverA2 = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000a2"))
  private val driverB1 = PersonId(UUID.fromString("00000002-0000-0000-0000-0000000000b1"))

  private def person(id: PersonId, name: String, company: CompanyId): Person = Person(
    id = id,
    name = name,
    email = s"${name.toLowerCase.replace(" ", ".")}@test.de",
    role = PersonRole.Driver,
    companyId = Some(company)
  )

  private val repoLayer: ZLayer[Any, Nothing, PersonRepository] = ZLayer {
    for
      repo <- ZIO.succeed(new InMemoryPersonRepository)
      _    <- repo.create(person(driverA1, "Hans Weber", companyA)).orDie
      _    <- repo.create(person(driverA2, "Erika Musterfrau", companyA)).orDie
      _    <- repo.create(person(driverB1, "Other Tenant", companyB)).orDie
    yield repo
  }

  def spec = suite("PersonNameLookup.names")(
    test("resolves names for ids of the given company") {
      for names <- PersonNameLookup.names(List(driverA1, driverA2), companyA)
      yield assertTrue(
        names.get(driverA1).contains("Hans Weber"),
        names.get(driverA2).contains("Erika Musterfrau")
      )
    },
    test("[TENANT ISOLATION] an id from another company resolves to no name") {
      for names <- PersonNameLookup.names(List(driverA1, driverB1), companyA)
      yield assertTrue(
        names.get(driverA1).contains("Hans Weber"),
        !names.contains(driverB1)
      )
    },
    test("unknown ids are simply absent") {
      for names <- PersonNameLookup.names(List(PersonId(UUID.randomUUID())), companyA)
      yield assertTrue(names.isEmpty)
    },
    test("empty id list resolves to an empty map without touching the repository") {
      val failingRepo: ZLayer[Any, Nothing, PersonRepository] = ZLayer.succeed(
        new PersonRepository:
          private def notImpl                                                                              = ZIO.die(new NotImplementedError("must not be called for empty ids"))
          def create(p: Person): Task[Person]                                                              = notImpl
          def findById(id: PersonId): Task[Option[Person]]                                                 = notImpl
          def findByIdAndCompany(id: PersonId, cid: CompanyId): Task[Option[Person]]                       = notImpl
          def findByEmail(email: String): Task[Option[Person]]                                             = notImpl
          def findByRole(role: PersonRole): Task[List[Person]]                                             = notImpl
          def findByRoleAndCompany(role: PersonRole, cid: CompanyId): Task[List[Person]]                   = notImpl
          def findByCompanyId(cid: CompanyId): Task[List[Person]]                                          = notImpl
          def findAll(): Task[List[Person]]                                                                = notImpl
          def update(p: Person): Task[Person]                                                              = notImpl
          def delete(id: PersonId): Task[Unit]                                                             = notImpl
          def deleteInCompany(id: PersonId, cid: CompanyId): Task[Unit]                                    = notImpl
          def findByStatus(status: UserStatus): Task[List[Person]]                                         = notImpl
          def searchByQuery(query: String): Task[List[Person]]                                             = notImpl
          def updateLastLogin(id: PersonId): Task[Unit]                                                    = notImpl
          def findByClientCompany(ccid: ClientCompanyId): Task[List[Person]]                               = notImpl
          def upsertDriverRow(pid: PersonId): Task[Unit]                                                   = notImpl
          def getAvatar(id: PersonId): Task[Option[(Array[Byte], String)]]                                 = notImpl
          def setAvatar(id: PersonId, cid: CompanyId, bytes: Array[Byte], contentType: String): Task[Unit] = notImpl
          def deleteAvatar(id: PersonId, cid: CompanyId): Task[Unit]                                       = notImpl
      )
      PersonNameLookup
        .names(Nil, companyA)
        .map(names => assertTrue(names.isEmpty))
        .provideLayer(failingRepo)
    }
  ).provide(repoLayer)
