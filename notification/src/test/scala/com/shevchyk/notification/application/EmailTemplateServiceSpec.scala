package com.shevchyk.notification.application

import com.shevchyk.core.application.InvoiceEmailData
import com.shevchyk.notification.config.SmtpConfig
import zio.*
import zio.test.*

import java.time.LocalDate

object EmailTemplateServiceSpec extends ZIOSpecDefault:

  private val defaultConfig = SmtpConfig(
    host = "localhost",
    port = 1025,
    user = "",
    password = "",
    from = "noreply@dispax.de",
    replyTo = None,
    security = "NONE",
    defaultLanguage = "de"
  )

  private val configLayer: ZLayer[Any, Nothing, SmtpConfig] = ZLayer.succeed(defaultConfig)

  private def makeData(
      lang: String,
      isReminder: Boolean = false,
      dueDate: Option[LocalDate] = None
  ): InvoiceEmailData = InvoiceEmailData(
    toEmail = "client@example.com",
    toName = "Test GmbH",
    invoiceNumber = "2024/042",
    totalAmount = BigDecimal("1234.56"),
    currency = "EUR",
    dueDate = dueDate,
    isReminder = isReminder,
    pdfAttachment = Array.empty[Byte],
    pdfFilename = "2024-042.pdf",
    language = lang
  )

  def spec = suite("EmailTemplateService")(
    suite("DE invoice")(
      test("subject contains invoice number and no placeholder tokens") {
        for
          svc    <- ZIO.service[EmailTemplateService]
          result <- svc.renderInvoice(makeData("de"))
        yield
          val (subj, plain, _) = result
          assertTrue(subj.contains("2024/042")) &&
          assertTrue(!subj.contains("{{")) &&
          assertTrue(!plain.contains("{{"))
      },
      test("plain body contains totalAmount and currency") {
        for
          svc    <- ZIO.service[EmailTemplateService]
          result <- svc.renderInvoice(makeData("de"))
        yield
          val (_, plain, html) = result
          assertTrue(plain.contains("1234.56")) &&
          assertTrue(plain.contains("EUR")) &&
          assertTrue(html.contains("1234.56")) &&
          assertTrue(html.contains("EUR"))
      }
    ),
    suite("EN invoice")(
      test("subject and body contain invoice number, no placeholder tokens") {
        for
          svc    <- ZIO.service[EmailTemplateService]
          result <- svc.renderInvoice(makeData("en"))
        yield
          val (subj, plain, _) = result
          assertTrue(subj.contains("2024/042")) &&
          assertTrue(!subj.contains("{{")) &&
          assertTrue(!plain.contains("{{"))
      }
    ),
    suite("UK invoice")(
      test("subject and body contain invoice number, no placeholder tokens") {
        for
          svc    <- ZIO.service[EmailTemplateService]
          result <- svc.renderInvoice(makeData("uk"))
        yield
          val (subj, plain, _) = result
          assertTrue(subj.contains("2024/042")) &&
          assertTrue(!subj.contains("{{")) &&
          assertTrue(!plain.contains("{{"))
      }
    ),
    suite("DE reminder")(
      test("subject contains reminder keyword and HTML body contains reminder badge") {
        for
          svc    <- ZIO.service[EmailTemplateService]
          result <- svc.renderInvoice(makeData("de", isReminder = true))
        yield
          val (subj, _, html) = result
          assertTrue(subj.contains("Zahlungserinnerung")) &&
          assertTrue(subj.contains("2024/042")) &&
          assertTrue(html.contains("Zahlungserinnerung"))
      }
    ),
    suite("EN reminder")(
      test("subject and HTML body contain reminder keyword") {
        for
          svc    <- ZIO.service[EmailTemplateService]
          result <- svc.renderInvoice(makeData("en", isReminder = true))
        yield
          val (subj, _, html) = result
          assertTrue(subj.contains("Payment Reminder")) &&
          assertTrue(html.contains("Payment Reminder"))
      }
    ),
    suite("UK reminder")(
      test("subject and HTML body contain invoice number") {
        for
          svc    <- ZIO.service[EmailTemplateService]
          result <- svc.renderInvoice(makeData("uk", isReminder = true))
        yield
          val (subj, _, html) = result
          assertTrue(subj.contains("2024/042")) &&
          assertTrue(html.contains("2024/042"))
      }
    ),
    suite("Language fallback")(
      test("unknown language 'fr' falls back to default 'de' without error") {
        for
          svc    <- ZIO.service[EmailTemplateService]
          result <- svc.renderInvoice(makeData("fr"))
        yield
          val (subj, plain, _) = result
          assertTrue(subj.contains("2024/042")) &&
          assertTrue(!plain.contains("{{"))
      }
    ),
    suite("dueDate = None")(
      test("no {{dueDate}} or {{dueDateRow}} tokens remain in output") {
        for
          svc    <- ZIO.service[EmailTemplateService]
          result <- svc.renderInvoice(makeData("de", dueDate = None))
        yield
          val (subj, plain, html) = result
          assertTrue(!subj.contains("{{")) &&
          assertTrue(!plain.contains("{{")) &&
          assertTrue(!html.contains("{{"))
      }
    ),
    suite("dueDate = Some(...)")(
      test("due date appears in HTML, no placeholder tokens remain") {
        val due = LocalDate.of(2024, 12, 31)
        for
          svc    <- ZIO.service[EmailTemplateService]
          result <- svc.renderInvoice(makeData("de", dueDate = Some(due)))
        yield
          val (subj, plain, html) = result
          assertTrue(!subj.contains("{{")) &&
          assertTrue(!plain.contains("{{")) &&
          assertTrue(!html.contains("{{")) &&
          assertTrue(html.contains("2024-12-31"))
      }
    ),
    suite("Caching")(
      test("second call with same data returns same subject as first call") {
        val data = makeData("de")
        for
          svc     <- ZIO.service[EmailTemplateService]
          result1 <- svc.renderInvoice(data)
          result2 <- svc.renderInvoice(data)
        yield
          val (subj1, _, _) = result1
          val (subj2, _, _) = result2
          assertTrue(subj1 == subj2)
      }
    )
  ).provideLayer(configLayer >>> EmailTemplateService.layer)
