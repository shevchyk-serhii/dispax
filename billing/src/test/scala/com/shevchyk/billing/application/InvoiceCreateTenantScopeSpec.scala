package com.shevchyk.billing.application

import com.shevchyk.billing.domain.*
import com.shevchyk.billing.repository.{
  ClientCompanyRepository,
  CompanyBillingProfileRepository,
  InvoiceRepository,
  UnbilledRide
}
import com.shevchyk.core.application.{EmailSmsService, InvoiceEmailData, RideConfirmationData}
import com.shevchyk.core.domain.{ClientCompany, ClientCompanyId, CompanyId, CreateClientCompanyRequest}
import zio.*
import zio.test.*

import java.time.LocalDate
import java.util.UUID

/**
 * Pure unit test for the tenant-isolation guard in `createInvoice`: the requested `clientCompanyId` must belong to the
 * caller's taxi company. `ClientCompanyRepository.findById` is not tenant-scoped, so without the guard a dispatcher of
 * company A could bind company B's client company to an invoice (leaking B's name/address/VAT/email into the
 * PDF/email).
 *
 * The client-company stub returns a company owned by a DIFFERENT taxi company; the guard must reject it as
 * `ClientCompanyNotFound` (404, indistinguishable from a missing company — existence is not leaked) BEFORE the invoice
 * is created. The positive case uses a same-company client company and expects a persisted invoice.
 *
 * Mutation check: drop the `cc.taxiCompanyId != taxiCompanyId` guard and the cross-tenant test goes red (the foreign
 * client company is accepted and an invoice is created).
 */
object InvoiceCreateTenantScopeSpec extends ZIOSpecDefault:

  private def boom: Nothing = throw new AssertionError("repository must not be reached in this scenario")

  private val callerCompany  = CompanyId(UUID.randomUUID())
  private val foreignCompany = CompanyId(UUID.randomUUID())
  private val ccId           = UUID.randomUUID()

  // Records whether `create` was reached, so the cross-tenant test can assert no invoice was persisted.
  private def invoiceRepoStub(created: Ref[Boolean]): InvoiceRepository =
    new InvoiceRepository:
      def nextInvoiceNumber(taxiCompanyId: CompanyId, year: Int): Task[String]                          = ZIO.succeed(s"INV-$year-00001")
      def create(invoice: Invoice): Task[Invoice]                                                       = created.set(true).as(invoice)
      def findById(id: InvoiceId): Task[Option[Invoice]]                                                = ZIO.die(boom)
      def findByCompany(t: CompanyId, s: Option[InvoiceStatus], l: Int, o: Int): Task[List[Invoice]]    = ZIO.die(boom)
      def update(invoice: Invoice): Task[Invoice]                                                       = ZIO.die(boom)
      def findOverdueUnpaid(now: java.time.Instant): Task[List[Invoice]]                                = ZIO.die(boom)
      def delete(id: InvoiceId, t: CompanyId): Task[Boolean]                                            = ZIO.die(boom)
      def addItems(items: List[InvoiceItem]): Task[Unit]                                                = ZIO.die(boom)
      def deleteItems(invoiceId: InvoiceId): Task[Unit]                                                 = ZIO.die(boom)
      def replaceItems(i: InvoiceId, t: CompanyId, items: List[InvoiceItem]): Task[Unit]                = ZIO.die(boom)
      def unlinkRides(invoiceId: InvoiceId, t: CompanyId): Task[Unit]                                   = ZIO.die(boom)
      def findBillableRides(
          t: CompanyId,
          c: ClientCompanyId,
          f: Option[LocalDate],
          to: Option[LocalDate]
      ): Task[List[UnbilledRide]] = ZIO.die(boom)
      def findRidesByIds(t: CompanyId, rideIds: List[UUID]): Task[List[UnbilledRide]]                   = ZIO.die(boom)
      def findRideForReceipt(t: CompanyId, rideId: UUID): Task[Option[UnbilledRide]]                    = ZIO.die(boom)
      def findAllPlatform(s: Option[InvoiceStatus], l: Int, o: Int): Task[List[Invoice]]                = ZIO.die(boom)
      def sumRevenueByCompany(f: java.time.Instant, to: java.time.Instant): Task[Map[UUID, BigDecimal]] = ZIO.die(boom)
      def countOverdueByCompany(): Task[Map[UUID, Int]]                                                 = ZIO.die(boom)

  // Returns a client company owned by `owner` regardless of the queried id.
  private def clientCompanyRepoOwnedBy(owner: CompanyId): ClientCompanyRepository =
    new ClientCompanyRepository:
      def findById(id: ClientCompanyId): Task[Option[ClientCompany]]                             = ZIO.some(
        ClientCompany(
          id = id,
          name = "Kunde GmbH",
          taxiCompanyId = owner,
          email = Some("kunde@example.de"),
          phone = None,
          address = Some("Musterstr. 1, München"),
          preferredLanguage = Some("de"),
          vatId = Some("DE123456789")
        )
      )
      def findByTaxiCompany(taxiCompanyId: CompanyId): Task[List[ClientCompany]]                 = ZIO.die(boom)
      def create(req: CreateClientCompanyRequest, taxiCompanyId: CompanyId): Task[ClientCompany] = ZIO.die(boom)
      def update(
          id: ClientCompanyId,
          taxiCompanyId: CompanyId,
          req: CreateClientCompanyRequest
      ): Task[Option[ClientCompany]] = ZIO.die(boom)
      def delete(id: ClientCompanyId, taxiCompanyId: CompanyId): Task[Boolean]                   = ZIO.die(boom)

  private val explodingProfileRepo: CompanyBillingProfileRepository =
    new CompanyBillingProfileRepository:
      def findByCompany(companyId: CompanyId): Task[Option[CompanyBillingProfile]]                           = ZIO.die(boom)
      def upsert(companyId: CompanyId, req: UpdateCompanyBillingProfileRequest): Task[CompanyBillingProfile] = ZIO.die(
        boom
      )

  private val noopEmail: EmailSmsService =
    new EmailSmsService:
      def sendRideConfirmation(data: RideConfirmationData): Task[Unit] = ZIO.unit
      def sendDriverAssignment(data: RideConfirmationData): Task[Unit] = ZIO.unit
      def sendInvoiceEmail(data: InvoiceEmailData): Task[Unit]         = ZIO.unit

  private def request = CreateInvoiceRequest(
    clientCompanyId = ccId,
    periodFrom = LocalDate.of(2026, 6, 1),
    periodTo = LocalDate.of(2026, 6, 30),
    taxRate = BigDecimal(19)
  )

  def spec =
    suite("InvoiceService.createInvoice tenant isolation (unit)")(
      test(
        "a client company owned by another taxi company is rejected as ClientCompanyNotFound and no invoice is created"
      ) {
        for {
          created    <- Ref.make(false)
          service     = InvoiceServiceImpl(
                          invoiceRepoStub(created),
                          clientCompanyRepoOwnedBy(foreignCompany),
                          explodingProfileRepo,
                          noopEmail
                        )
          res        <- service.createInvoice(callerCompany, request).either
          wasCreated <- created.get
        } yield assertTrue(
          res match
            case Left(InvoiceError.ClientCompanyNotFound(id)) => id == ccId
            case _                                            => false,
          !wasCreated
        )
      },
      test("a client company owned by the caller's taxi company is accepted and the invoice is created") {
        for {
          created    <- Ref.make(false)
          service     = InvoiceServiceImpl(
                          invoiceRepoStub(created),
                          clientCompanyRepoOwnedBy(callerCompany),
                          explodingProfileRepo,
                          noopEmail
                        )
          res        <- service.createInvoice(callerCompany, request).either
          wasCreated <- created.get
        } yield assertTrue(
          res match
            case Right(inv) => inv.taxiCompanyId == callerCompany && inv.clientCompanyId.value == ccId
            case _          => false,
          wasCreated
        )
      }
    )
