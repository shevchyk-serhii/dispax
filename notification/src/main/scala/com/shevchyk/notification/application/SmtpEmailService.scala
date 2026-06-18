package com.shevchyk.notification.application

import com.shevchyk.core.application.{EmailSmsService, InvoiceEmailData, RideConfirmationData}
import com.shevchyk.notification.config.SmtpConfig
import jakarta.activation.DataHandler
import jakarta.mail.internet.{InternetAddress, MimeBodyPart, MimeMessage, MimeMultipart}
import jakarta.mail.util.ByteArrayDataSource
import jakarta.mail.{Message, Session, Transport}
import zio.*

import java.util.Properties

/**
 * Production `EmailSmsService` implementation backed by Jakarta Mail over SMTP.
 *
 * PII / privacy rules (mirroring `LoggingEmailSmsService`):
 *   - Do NOT log `data.toEmail`, `data.totalAmount`, or any rendered email body.
 *   - Log only the invoice number and PDF filename (non-PII operational metadata).
 *
 * All Jakarta Mail calls are wrapped in `ZIO.attemptBlocking` so they run on the blocking thread pool and never block a
 * ZIO fiber. On SMTP failure the `Task[Unit]` propagates the `MessagingException` as a typed ZIO error — the caller
 * (`InvoiceService`) maps it to `InvoiceError.EmailDeliveryError`.
 *
 * `sendRideConfirmation` / `sendDriverAssignment` are out of scope for SMTP delivery and remain as log stubs (identical
 * to `LoggingEmailSmsService`) to avoid any regression.
 */
class SmtpEmailService(config: SmtpConfig, templateService: EmailTemplateService) extends EmailSmsService:

  override def sendRideConfirmation(data: RideConfirmationData): Task[Unit] = ZIO.logInfo(
    s"[SMTP] Ride confirmation stub | ride: ${data.rideId}"
  )

  override def sendDriverAssignment(data: RideConfirmationData): Task[Unit] = ZIO.logInfo(
    s"[SMTP] Driver assignment stub | ride: ${data.rideId}"
  )

  override def sendInvoiceEmail(data: InvoiceEmailData): Task[Unit] =
    ZIO.logInfo(
      s"[SMTP] Sending invoice email | invoice: ${data.invoiceNumber} | attachment: ${data.pdfFilename} (${data.pdfAttachment.length} bytes)"
    ) *>
      templateService.renderInvoice(data).flatMap { case (subject, plain, html) =>
        ZIO.attemptBlocking {
          val session = buildSession()
          val msg     = buildMessage(session, data, subject, plain, html)
          Transport.send(msg, config.user, config.password)
        }
      } *>
      ZIO.logInfo(s"[SMTP] Invoice email delivered | invoice: ${data.invoiceNumber}")

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private def buildSession(): Session =
    val props = new Properties()
    props.put("mail.smtp.host", config.host)
    props.put("mail.smtp.port", config.port.toString)
    props.put("mail.smtp.auth", "true")
    config.security.toUpperCase match
      case "STARTTLS" =>
        // Port 587: negotiate STARTTLS after connecting on a plain socket.
        props.put("mail.smtp.starttls.enable", "true"): Unit
      case "SSL"      =>
        // Port 465: implicit SSL/TLS from the start (no STARTTLS negotiation).
        props.put("mail.smtp.ssl.enable", "true"): Unit
        props.put("mail.smtp.starttls.enable", "false"): Unit
      case _          =>
        // "NONE" (default) — plain TCP, no TLS properties set; for dev/MailHog/GreenMail.
        ()
    Session.getInstance(props)

  private def buildMessage(
      session: Session,
      data: InvoiceEmailData,
      subject: String,
      plainBody: String,
      htmlBody: String
  ): MimeMessage =
    val msg = new MimeMessage(session)
    msg.setFrom(new InternetAddress(config.from))
    config.replyTo.foreach(rt => msg.setReplyTo(Array(new InternetAddress(rt))))
    msg.setRecipient(Message.RecipientType.TO, new InternetAddress(data.toEmail))
    msg.setSubject(subject, "UTF-8")

    // Outer multipart/mixed: alternative body + PDF attachment
    val mixed = new MimeMultipart("mixed")

    // Inner multipart/alternative: plain text (first) + HTML (last, preferred by RFC-2046 clients)
    val alternative = new MimeMultipart("alternative")

    val plainPart = new MimeBodyPart()
    plainPart.setText(plainBody, "UTF-8", "plain")
    alternative.addBodyPart(plainPart)

    val htmlPart = new MimeBodyPart()
    htmlPart.setText(htmlBody, "UTF-8", "html")
    alternative.addBodyPart(htmlPart)

    val alternativeWrapper = new MimeBodyPart()
    alternativeWrapper.setContent(alternative)
    mixed.addBodyPart(alternativeWrapper)

    // PDF attachment
    val pdfPart   = new MimeBodyPart()
    val pdfSource = new ByteArrayDataSource(data.pdfAttachment, "application/pdf")
    pdfPart.setDataHandler(new DataHandler(pdfSource))
    pdfPart.setDisposition(jakarta.mail.Part.ATTACHMENT)
    pdfPart.setFileName(data.pdfFilename)
    mixed.addBodyPart(pdfPart)

    msg.setContent(mixed)
    msg

object SmtpEmailService:

  val layer: ZLayer[SmtpConfig & EmailTemplateService, Nothing, EmailSmsService] = ZLayer.fromFunction(
    new SmtpEmailService(_, _)
  )

  /**
   * Combined layer: reads `SmtpConfig` from HOCON/env, builds `EmailTemplateService`, then `SmtpEmailService`.
   */
  val liveLayer: ZLayer[Any, Nothing, EmailSmsService] =
    SmtpConfig.liveLayer >>> (ZLayer.service[SmtpConfig] ++ EmailTemplateService.layer) >>> layer
