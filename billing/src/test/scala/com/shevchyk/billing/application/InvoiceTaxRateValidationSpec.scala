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
 * Pure unit test (no DB, no Testcontainers) for the tax-rate guard added to `generateRideReceipt`. The repositories are
 * exploding stubs: an out-of-range tax rate must fail with `InvalidTaxRate` *before* any repository is touched. If the
 * guard is removed, the service reaches `findRideForReceipt`, the stub dies, and these tests go red — the mutation
 * check this fix needs.
 */
object InvoiceTaxRateValidationSpec extends ZIOSpecDefault:

  // Any repository call here means the guard did NOT short-circuit — fail loudly.
  // `def` (not `val`): the failure must arise when a method is *called*, not when
  // the stub is constructed.
  private def boom: Nothing = throw new AssertionError("repository must not be reached when tax rate is invalid")

  private val explodingInvoiceRepo: InvoiceRepository =
    new InvoiceRepository:
      def nextInvoiceNumber(taxiCompanyId: CompanyId, year: Int): Task[String]                          = ZIO.die(boom)
      def create(invoice: Invoice): Task[Invoice]                                                       = ZIO.die(boom)
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

  private val explodingClientCompanyRepo: ClientCompanyRepository =
    new ClientCompanyRepository:
      def findById(id: ClientCompanyId): Task[Option[ClientCompany]]                             = ZIO.die(boom)
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

  private val service: InvoiceService = InvoiceServiceImpl(
    explodingInvoiceRepo,
    explodingClientCompanyRepo,
    explodingProfileRepo,
    noopEmail
  )

  private val companyId = CompanyId(UUID.randomUUID())
  private val rideId    = UUID.randomUUID()

  def spec =
    suite("InvoiceService.generateRideReceipt tax-rate guard (unit)")(
      test("taxRate = -100 fails with InvalidTaxRate before any repository call") {
        for {
          res <- service.generateRideReceipt(rideId, companyId, BigDecimal("-100"), "Acme GmbH").either
        } yield assertTrue(res match
          case Left(InvoiceError.InvalidTaxRate(rate)) => rate == BigDecimal("-100")
          case _                                       => false
        )
      },
      test("a negative taxRate fails with InvalidTaxRate before any repository call") {
        for {
          res <- service.generateRideReceipt(rideId, companyId, BigDecimal("-1"), "Acme GmbH").either
        } yield assertTrue(res match
          case Left(InvoiceError.InvalidTaxRate(rate)) => rate == BigDecimal("-1")
          case _                                       => false
        )
      },
      test("a taxRate above 100 fails with InvalidTaxRate before any repository call") {
        for {
          res <- service.generateRideReceipt(rideId, companyId, BigDecimal("101"), "Acme GmbH").either
        } yield assertTrue(res match
          case Left(InvoiceError.InvalidTaxRate(rate)) => rate == BigDecimal("101")
          case _                                       => false
        )
      }
    )
