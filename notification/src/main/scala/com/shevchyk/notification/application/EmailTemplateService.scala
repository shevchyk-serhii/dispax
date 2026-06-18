package com.shevchyk.notification.application

import com.shevchyk.core.application.InvoiceEmailData
import com.shevchyk.notification.config.SmtpConfig
import zio.*

import scala.io.Source

/**
 * Loads invoice/reminder email templates from classpath resources and substitutes placeholders.
 *
 * Template convention:
 *   - File: `templates/<lang>/<kind>.txt` or `templates/<lang>/<kind>.html`
 *   - Line 1: subject
 *   - Line 2: blank separator
 *   - Line 3+: body
 *
 * Placeholders (double-brace, replaced with str-replace): {{invoiceNumber}}, {{totalAmount}}, {{currency}},
 * {{dueDate}}, {{toName}}, {{dueDateRow}}
 *
 * {{dueDate}} in .txt files is substituted with either ", fällig am <date>" style text (language-neutral: the service
 * inserts the raw ISO date with a configurable prefix per locale) or an empty string. {{dueDateRow}} in .html files is
 * substituted with a pre-built <tr>…</tr> snippet or empty string.
 *
 * Caching: each (lang, kind, format) triplet is loaded once on first use and stored in a Ref-backed map. Fallback:
 * unknown/unsupported language → defaultLang (from SmtpConfig.defaultLanguage).
 */
trait EmailTemplateService:
  /**
   * Render invoice or reminder template for the language specified in `data.language`. Returns (subject, plainText,
   * html).
   */
  def renderInvoice(data: InvoiceEmailData): Task[(String, String, String)]

object EmailTemplateService:

  private val supportedLangs: Set[String] = Set("de", "en", "uk")

  final private case class CacheKey(lang: String, kind: String, format: String)

  final private case class RawTemplate(subject: String, body: String)

  val layer: ZLayer[SmtpConfig, Nothing, EmailTemplateService] = ZLayer.fromZIO(
    for
      config <- ZIO.service[SmtpConfig]
      cache  <- Ref.make(Map.empty[CacheKey, RawTemplate])
    yield new Live(config.defaultLanguage, cache)
  )

  final private class Live(defaultLang: String, cache: Ref[Map[CacheKey, RawTemplate]]) extends EmailTemplateService:

    override def renderInvoice(data: InvoiceEmailData): Task[(String, String, String)] =
      val lang = if supportedLangs.contains(data.language) then data.language else defaultLang
      val kind = if data.isReminder then "reminder" else "invoice"
      for
        plain    <- renderTemplate(lang, kind, "txt", data)
        html     <- renderTemplate(lang, kind, "html", data)
        subject   = extractSubject(plain)
        plainBody = extractBody(plain)
        htmlBody  = extractBody(html)
      yield (subject, plainBody, htmlBody)

    private def renderTemplate(lang: String, kind: String, format: String, data: InvoiceEmailData): Task[String] =
      val key = CacheKey(lang, kind, format)
      for
        cached  <- cache.get.map(_.get(key))
        raw     <-
          cached match
            case Some(r) => ZIO.succeed(r)
            case None    => loadAndCache(lang, kind, format, key)
        rendered = substitute(raw.subject + "\n\n" + raw.body, data, format)
      yield rendered

    private def loadAndCache(lang: String, kind: String, format: String, key: CacheKey): Task[RawTemplate] =
      for
        content <- loadResource(s"templates/$lang/$kind.$format")
                     .catchAll(_ =>
                       // Fallback to defaultLang if the requested lang file is missing
                       if lang != defaultLang then loadResource(s"templates/$defaultLang/$kind.$format")
                       else ZIO.fail(new RuntimeException(s"Missing template: templates/$lang/$kind.$format"))
                     )
        raw      = parseTemplate(content)
        _       <- cache.update(_ + (key -> raw))
      yield raw

    private def loadResource(path: String): Task[String] =
      ZIO.acquireReleaseWith(
        ZIO.attemptBlocking {
          val stream = getClass.getClassLoader.getResourceAsStream(path)
          if stream == null then throw new RuntimeException(s"Template resource not found on classpath: $path")
          stream
        }
      )(stream => ZIO.succeed(stream.close())) { stream =>
        ZIO.attemptBlocking(Source.fromInputStream(stream, "UTF-8").mkString)
      }

    private def parseTemplate(content: String): RawTemplate =
      // Split on the FIRST blank line (two consecutive newlines).
      // Everything before the first blank line is the subject; everything after is the body.
      val idx = content.indexOf("\n\n")
      if idx < 0 then RawTemplate(content.trim, "")
      else RawTemplate(content.substring(0, idx).trim, content.substring(idx + 2).trim)

    private def extractSubject(rendered: String): String =
      val idx = rendered.indexOf("\n\n")
      if idx < 0 then rendered.trim else rendered.substring(0, idx).trim

    private def extractBody(rendered: String): String =
      val idx = rendered.indexOf("\n\n")
      if idx < 0 then "" else rendered.substring(idx + 2).trim

    private def substitute(template: String, data: InvoiceEmailData, format: String): String =
      val dueDateStr: String =
        data.dueDate.fold("") { d =>
          if format == "txt" then s", fällig am $d" else d.toString
        }

      val dueDateRowHtml: String =
        data.dueDate.fold("") { d =>
          val colorStyle = if data.isReminder then " color:#c0392b;" else ""
          s"""<tr><td style="padding:6px 0;color:#555;">Fälligkeitsdatum</td>
    <td style="padding:6px 0;font-weight:bold;$colorStyle">$d</td></tr>"""
        }

      template
        .replace("{{invoiceNumber}}", data.invoiceNumber)
        .replace("{{totalAmount}}", data.totalAmount.toString)
        .replace("{{currency}}", data.currency)
        .replace("{{toName}}", data.toName)
        .replace("{{dueDate}}", dueDateStr)
        .replace("{{dueDateRow}}", dueDateRowHtml)
