package com.shevchyk.notification.integration

import com.icegreen.greenmail.util.{GreenMail, ServerSetup}
import com.shevchyk.core.application.InvoiceEmailData
import com.shevchyk.notification.application.SmtpEmailService
import com.shevchyk.notification.config.SmtpConfig
import jakarta.mail.internet.MimeMessage
import jakarta.mail.Multipart
import zio.*
import zio.test.*

import java.time.LocalDate

/**
 * GreenMail-based integration tests for `SmtpEmailService`.
 *
 * GreenMail is in-process (no Docker / Testcontainers needed). Each suite starts its own `GreenMail` instance on a
 * dedicated port to avoid port conflicts when tests run in sequence.
 */
object SmtpEmailServiceSpec extends ZIOSpecDefault:

  /**
   * Base invoice data reused across tests (isReminder / pdfAttachment overridden per suite).
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
    pdfFilename = "2024-001.pdf"
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

  def spec =
    suite("SmtpEmailService")(
      suite("sendInvoiceEmail — first send")(
        test("delivers message with correct recipient, subject, and PDF attachment") {
          // GreenMail on port 3025 (avoids clashing with system SMTP or other test suites)
          val setup     = new ServerSetup(3025, "127.0.0.1", ServerSetup.PROTOCOL_SMTP)
          val greenMail = new GreenMail(setup)
          greenMail.start()
          // GreenMail 2.x: create user so auth succeeds
          greenMail.setUser("client@test.com", "test", "test")

          val config  = SmtpConfig(
            host = "127.0.0.1",
            port = 3025,
            user = "test",
            password = "test",
            from = "noreply@dispax.de",
            replyTo = None,
            startTls = false
          )
          val service = new SmtpEmailService(config)

          val result =
            for
              _       <- service.sendInvoiceEmail(baseData)
              received = greenMail.getReceivedMessages
            yield
              val msg        = received(0)
              val to         = msg.getAllRecipients.map(_.toString).mkString
              val subj       = msg.getSubject
              val pdfPartOpt = findPart(msg, "application/pdf")
              assertTrue(received.length == 1) &&
              assertTrue(to.contains("client@test.com")) &&
              assertTrue(subj.contains("2024/001")) &&
              assertTrue(!subj.contains("Zahlungserinnerung")) &&
              assertTrue(pdfPartOpt.isDefined) &&
              assertTrue(pdfPartOpt.exists(_.getFileName == "2024-001.pdf")) &&
              assertTrue(msg.getContent.isInstanceOf[Multipart])

          result.ensuring(ZIO.succeed(greenMail.stop()))
        }
      ),
      suite("sendInvoiceEmail — reminder")(
        test("subject contains Zahlungserinnerung and HTML body marks reminder") {
          val setup     = new ServerSetup(3026, "127.0.0.1", ServerSetup.PROTOCOL_SMTP)
          val greenMail = new GreenMail(setup)
          greenMail.start()
          greenMail.setUser("client@test.com", "test", "test")

          val config  = SmtpConfig(
            host = "127.0.0.1",
            port = 3026,
            user = "test",
            password = "test",
            from = "noreply@dispax.de",
            replyTo = None,
            startTls = false
          )
          val service = new SmtpEmailService(config)
          val data    = baseData.copy(isReminder = true)

          val result =
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

          result.ensuring(ZIO.succeed(greenMail.stop()))
        }
      ),
      suite("sendInvoiceEmail — SMTP failure propagates")(
        test("ZIO effect fails when no SMTP listener is running (no throw)") {
          // Point at a port with no listener — no GreenMail started here.
          val config  = SmtpConfig(
            host = "127.0.0.1",
            port = 19999,
            user = "x",
            password = "x",
            from = "noreply@dispax.de",
            replyTo = None,
            startTls = false
          )
          val service = new SmtpEmailService(config)

          for exit <- service.sendInvoiceEmail(baseData).exit
          yield assertTrue(exit.isFailure)
        }
      )
    )
