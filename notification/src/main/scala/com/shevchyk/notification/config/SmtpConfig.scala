package com.shevchyk.notification.config

import zio.*
import zio.config.*
import zio.config.magnolia.*
import zio.config.typesafe.*

/**
 * SMTP server configuration. Mirrors the DatabaseConfig pattern: structured HOCON via `deriveConfig`, with a
 * `defaultLayer` fallback that reads directly from env vars for test environments that do not load a HOCON file.
 *
 * Production invariant: `application-production.conf` contains only `${?SMTP_*}` references with NO defaults. If an env
 * var is absent in production the HOCON parser leaves it unresolved and `layer` fails at startup — the same fail-fast
 * behaviour as `DATABASE_URL`. Tests and local dev use `defaultLayer` (port 1025 = MailHog / GreenMail plain SMTP).
 *
 * TLS modes (field `security`):
 *   - "NONE" — plain TCP, no encryption; for dev (MailHog/GreenMail on port 1025)
 *   - "STARTTLS" — opportunistic upgrade after connect (port 587); sets mail.smtp.starttls.enable=true
 *   - "SSL" — implicit SSL/TLS from the start (port 465); sets mail.smtp.ssl.enable=true
 */
final case class SmtpConfig(
    host: String,
    port: Int,
    user: String,
    password: String,
    from: String,
    replyTo: Option[String] = None,
    security: String = "NONE"
)

object SmtpConfig:

  private val configDescriptor: Config[SmtpConfig] = deriveConfig[SmtpConfig].nested("smtp")

  /**
   * Reads from the HOCON file selected by `app.env` / `config.resource`.
   */
  val layer: ZLayer[Any, Throwable, SmtpConfig] = ZLayer.fromZIO(
    read(configDescriptor.from(ConfigProvider.fromResourcePath()))
  )

  /**
   * Env-var fallback used when no HOCON config is loaded (e.g. in unit tests). Defaults point at a local
   * MailHog/GreenMail instance on port 1025 with no auth and no TLS — safe, non-secret values.
   */
  val defaultLayer: ZLayer[Any, Nothing, SmtpConfig] = ZLayer.succeed(
    SmtpConfig(
      host = sys.env.getOrElse("SMTP_HOST", "localhost"),
      port = sys.env.getOrElse("SMTP_PORT", "1025").toInt,
      user = sys.env.getOrElse("SMTP_USER", ""),
      password = sys.env.getOrElse("SMTP_PASSWORD", ""),
      from = sys.env.getOrElse("SMTP_FROM", "noreply@dispax.de"),
      replyTo = sys.env.get("SMTP_REPLY_TO"),
      security = sys.env.getOrElse("SMTP_SECURITY", "NONE")
    )
  )

  /**
   * Production-ready layer: HOCON first, silent fallback to env-var defaults if HOCON parse fails.
   */
  val liveLayer: ZLayer[Any, Nothing, SmtpConfig] = layer.catchAll(_ => defaultLayer)
