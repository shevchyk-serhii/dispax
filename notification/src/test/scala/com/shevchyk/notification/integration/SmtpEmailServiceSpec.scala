package com.shevchyk.notification.integration

import com.icegreen.greenmail.util.{GreenMail, ServerSetup}
import com.shevchyk.core.application.InvoiceEmailData
import com.shevchyk.notification.application.{EmailTemplateService, SmtpEmailService}
import com.shevchyk.notification.config.SmtpConfig
import jakarta.mail.internet.MimeMessage
import jakarta.mail.Multipart
import zio.*
import zio.test.*

import java.time.LocalDate

/**
 * GreenMail-based integration tests for `SmtpEmailService`.
 *
 * GreenMail is in-process (no Docker / Testcontainers needed). Each test starts its own `GreenMail` instance on a
 * dedicated port to avoid port conflicts when tests run in parallel.
 *
 * All tests use `security = "NONE"` (plain TCP) — the real dev scenario (MailHog/GreenMail on port 1025). GreenMail
 * listens on a plain TCP socket with no TLS negotiation, and `SmtpEmailService` must connect successfully without
 * setting any TLS properties.
 */
object SmtpEmailServiceSpec extends ZIOSpecDefault:

  /**
   * Base invoice data reused across tests.
   */
  private val baseData = InvoiceEmailData(
    toEmail = "client@test.com",
    toName = "Test GmbH",
    invoiceNumber = "2024/001",
    totalAmount = BigDecimal(1500),
    currency = "EUR",
    dueDate = Some(LocalDate.of(2024, 12, 31)),
    isReminder = false,
    pdfAttachment = Array[Byte](1, 2, 3),
    pdfFilename = "2024-001.pdf",
    language = "de"
  )

  /**
   * Walk a `MimeMessage` multipart tree and return the first body part whose content-type starts with the given prefix
   * (case-insensitive).
   */
  private def findPart(msg: MimeMessage, contentTypePrefix: String): Option[jakarta.mail.BodyPart] =
    def search(mp: Multipart): Option[jakarta.mail.BodyPart] =
      (0 until mp.getCount).view.flatMap { i =>
        val bp = mp.getBodyPart(i)
        if bp.getContentType.toLowerCase.startsWith(contentTypePrefix.toLowerCase) then Some(bp)
        else
          bp.getContent match
            case nested: Multipart => search(nested)
            case _                 => None
      }.headOption

    msg.getContent match
      case mp: Multipart => search(mp)
      case _             => None

  /**
   * Allocate a GreenMail SMTP server on the given port, run `test` inside it, then shut it down regardless of outcome.
   * The registered user `login="gmtest"` / `password="gmtest"` is accepted by GreenMail as the SMTP AUTH credential.
   *
   * We use `security = "NONE"` — plain TCP, the real dev scenario (MailHog/GreenMail port 1025). No TLS properties are
   * set, so Jakarta Mail connects on a plain socket and proceeds directly to AUTH.
   */
  private def withGreenMail(
      port: Int
  )(body: (SmtpEmailService, GreenMail) => Task[TestResult]): Task[TestResult] =
    ZIO.acquireReleaseWith(
      ZIO.succeed {
        val setup     = new ServerSetup(port, "127.0.0.1", ServerSetup.PROTOCOL_SMTP)
        val greenMail = new GreenMail(setup)
        greenMail.start()
        greenMail.setUser("client@test.com", "gmtest", "gmtest")
        greenMail
      }
    )(gm => ZIO.succeed(gm.stop())) { greenMail =>
      val config = SmtpConfig(
        host = "127.0.0.1",
        port = port,
        user = "gmtest",
        password = "gmtest",
        from = "noreply@dispax.de",
        replyTo = None,
        security = "NONE", // plain TCP — the real dev scenario (MailHog/GreenMail, no TLS)
        defaultLanguage = "de"
      )
      for
        templateService <- ZIO
                             .service[EmailTemplateService]
                             .provideLayer(
                               ZLayer.succeed(config) >>> EmailTemplateService.layer
                             )
        result          <- body(new SmtpEmailService(config, templateService), greenMail)
      yield result
    }

  def spec =
    suite("SmtpEmailService")(
      // -----------------------------------------------------------------------
      // Criterion (a): real email with PDF attachment delivered
      // -----------------------------------------------------------------------
      suite("sendInvoiceEmail — first send")(
        test("delivers message with correct recipient, subject, and PDF attachment") {
          withGreenMail(3025) { (service, greenMail) =>
            for
              _       <- service.sendInvoiceEmail(baseData)
              received = greenMail.getReceivedMessages
            yield
              val msg        = received(0)
              val to         = msg.getAllRecipients.map(_.toString).mkString(",")
              val subj       = msg.getSubject
              val pdfPartOpt = findPart(msg, "application/pdf")
              assertTrue(received.length == 1) &&
              assertTrue(to.contains("client@test.com")) &&
              assertTrue(subj.contains("2024/001")) &&
              assertTrue(!subj.contains("Zahlungserinnerung")) &&
              assertTrue(pdfPartOpt.isDefined) &&
              assertTrue(pdfPartOpt.exists(_.getFileName == "2024-001.pdf")) &&
              assertTrue(msg.getContent.isInstanceOf[Multipart])
          }
        }
      ),

      // -----------------------------------------------------------------------
      // Criterion (a) + (b-tester): reminder email
      // -----------------------------------------------------------------------
      suite("sendInvoiceEmail — reminder")(
        test("subject contains Zahlungserinnerung and HTML body marks reminder") {
          withGreenMail(3026) { (service, greenMail) =>
            val data = baseData.copy(isReminder = true)
            for
              _       <- service.sendInvoiceEmail(data)
              received = greenMail.getReceivedMessages
            yield
              val msg      = received(0)
              val subj     = msg.getSubject
              val htmlPart = findPart(msg, "text/html")
              assertTrue(subj.contains("Zahlungserinnerung")) &&
              assertTrue(subj.contains("2024/001")) &&
              assertTrue(htmlPart.isDefined) &&
              assertTrue(htmlPart.exists(_.getContent.toString.contains("Zahlungserinnerung")))
          }
        }
      ),

      // -----------------------------------------------------------------------
      // Criterion (c): ZIO-only — SMTP failure must propagate as ZIO failure, not throw
      // -----------------------------------------------------------------------
      suite("sendInvoiceEmail — SMTP failure propagates")(
        test("ZIO effect fails when no SMTP listener is running (no throw)") {
          // Port 19999 — no GreenMail started here; connection must be refused.
          val config = SmtpConfig(
            host = "127.0.0.1",
            port = 19999,
            user = "x",
            password = "x",
            from = "noreply@dispax.de",
            replyTo = None,
            security = "NONE",
            defaultLanguage = "de"
          )
          for
            templateService <- ZIO
                                 .service[EmailTemplateService]
                                 .provideLayer(
                                   ZLayer.succeed(config) >>> EmailTemplateService.layer
                                 )
            service          = new SmtpEmailService(config, templateService)
            exit            <- service.sendInvoiceEmail(baseData).exit
          yield assertTrue(exit.isFailure)
        }
      )
    ) @@ TestAspect.sequential
