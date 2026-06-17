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
class SmtpEmailService(config: SmtpConfig) extends EmailSmsService:

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
      ZIO.attemptBlocking {
        val session = buildSession()
        val msg     = buildMessage(session, data)
        Transport.send(msg, config.user, config.password)
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
    if config.startTls then
      // Port 587: negotiate STARTTLS after connecting on a plain socket.
      props.put("mail.smtp.starttls.enable", "true"): Unit
    else
      // Port 465: implicit SSL from the start (no STARTTLS negotiation).
      props.put("mail.smtp.ssl.enable", "true"): Unit
      // Disable STARTTLS when using implicit SSL to avoid double-negotiation.
      props.put("mail.smtp.starttls.enable", "false"): Unit
    Session.getInstance(props)

  private def buildMessage(session: Session, data: InvoiceEmailData): MimeMessage =
    val msg = new MimeMessage(session)
    msg.setFrom(new InternetAddress(config.from))
    config.replyTo.foreach(rt => msg.setReplyTo(Array(new InternetAddress(rt))))
    msg.setRecipient(Message.RecipientType.TO, new InternetAddress(data.toEmail))
    msg.setSubject(subject(data), "UTF-8")

    // Outer multipart/mixed: alternative body + PDF attachment
    val mixed = new MimeMultipart("mixed")

    // Inner multipart/alternative: plain text (first) + HTML (last, preferred by RFC-2046 clients)
    val alternative = new MimeMultipart("alternative")

    val plainPart = new MimeBodyPart()
    plainPart.setText(plainBody(data), "UTF-8", "plain")
    alternative.addBodyPart(plainPart)

    val htmlPart = new MimeBodyPart()
    htmlPart.setText(htmlBody(data), "UTF-8", "html")
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

  private def subject(data: InvoiceEmailData): String =
    if data.isReminder then s"Zahlungserinnerung: Rechnung ${data.invoiceNumber}"
    else s"Ihre Rechnung ${data.invoiceNumber} von Dispax"

  private def plainBody(data: InvoiceEmailData): String =
    // PII rule: do NOT embed data.toEmail or data.totalAmount in logged strings.
    // Body text itself is safe to compose — it is only delivered via SMTP, not logged.
    if data.isReminder then
      val dueLine = data.dueDate.fold("")(d => s", fällig am $d")
      s"""Sehr geehrte Damen und Herren,

dies ist eine Zahlungserinnerung für Rechnung ${data.invoiceNumber} über ${data.totalAmount} ${data.currency}$dueLine.

Bitte begleichen Sie den offenen Betrag so bald wie möglich. Den Rechnungsbeleg finden Sie im Anhang.

Mit freundlichen Grüßen
Ihr Dispax-Team"""
    else s"""Sehr geehrte Damen und Herren,

anbei erhalten Sie Ihre Rechnung ${data.invoiceNumber} über ${data.totalAmount} ${data.currency}.

Den Rechnungsbeleg finden Sie im Anhang dieser E-Mail.

Mit freundlichen Grüßen
Ihr Dispax-Team"""

  private def htmlBody(data: InvoiceEmailData): String =
    val reminderBadge =
      if data.isReminder then
        """<p style="background:#fff3cd;border:1px solid #ffc107;padding:12px 16px;border-radius:4px;color:#856404;font-weight:bold;">
          |  Zahlungserinnerung
          |</p>""".stripMargin
      else ""

    val dueDateRow =
      data.dueDate.fold("") { d =>
        val color = if data.isReminder then " color:#c0392b;" else ""
        s"""<tr><td style="padding:6px 0;color:#555;">Fälligkeitsdatum</td>
           |    <td style="padding:6px 0;font-weight:bold;$color">$d</td></tr>""".stripMargin
      }

    s"""<!DOCTYPE html>
       |<html lang="de">
       |<head><meta charset="UTF-8"><title>${subject(data)}</title></head>
       |<body style="font-family:Arial,sans-serif;background:#f4f4f4;margin:0;padding:24px;">
       |  <div style="max-width:600px;margin:0 auto;background:#fff;border-radius:8px;padding:32px;box-shadow:0 2px 8px rgba(0,0,0,.08);">
       |    <h1 style="color:#2c3e50;font-size:22px;margin-top:0;">${subject(data)}</h1>
       |    $reminderBadge
       |    <p style="color:#333;">Sehr geehrte Damen und Herren,</p>
       |    <p style="color:#333;">
       |      ${
        if data.isReminder then s"dies ist eine Zahlungserinnerung für Rechnung <strong>${data.invoiceNumber}</strong>."
        else s"anbei erhalten Sie Ihre Rechnung <strong>${data.invoiceNumber}</strong>."
      }
       |    </p>
       |    <table style="width:100%;border-collapse:collapse;margin:16px 0;">
       |      <tr><td style="padding:6px 0;color:#555;">Rechnungsnummer</td>
       |          <td style="padding:6px 0;font-weight:bold;">${data.invoiceNumber}</td></tr>
       |      <tr><td style="padding:6px 0;color:#555;">Betrag</td>
       |          <td style="padding:6px 0;font-weight:bold;">${data.totalAmount} ${data.currency}</td></tr>
       |      $dueDateRow
       |    </table>
       |    <p style="color:#333;">Den Rechnungsbeleg finden Sie im Anhang dieser E-Mail.</p>
       |    <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
       |    <p style="color:#777;font-size:13px;">Mit freundlichen Grüßen<br>Ihr Dispax-Team</p>
       |  </div>
       |</body>
       |</html>""".stripMargin

object SmtpEmailService:

  val layer: ZLayer[SmtpConfig, Nothing, EmailSmsService] = ZLayer.fromFunction(new SmtpEmailService(_))

  /**
   * Combined layer: reads `SmtpConfig` from HOCON/env, then builds `SmtpEmailService`.
   */
  val liveLayer: ZLayer[Any, Nothing, EmailSmsService] = SmtpConfig.liveLayer >>> layer
