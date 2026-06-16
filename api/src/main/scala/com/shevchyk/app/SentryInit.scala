package com.shevchyk.app

import com.shevchyk.core.config.Environment
import io.sentry.Sentry

/**
 * Sentry bootstrap. Initialised once at startup from environment variables:
 *
 *   - `SENTRY_DSN`         — the project DSN. When empty/unset, Sentry stays disabled and every call here is a no-op,
 *                            so local and dev runs need no extra configuration.
 *   - `SENTRY_ENVIRONMENT` — falls back to the app environment (development/production) when not set explicitly.
 *   - `SENTRY_RELEASE`     — optional release/version tag for grouping issues per deploy.
 *
 * Errors are reported two ways: the logback [[io.sentry.logback.SentryAppender]] forwards WARN+ logs, and the global
 * HTTP error handler calls [[capture]] to attach the real Throwable for accurate grouping.
 */
object SentryInit {

  def init(): Unit = {
    val dsn = sys.env.getOrElse("SENTRY_DSN", "").trim
    if (dsn.nonEmpty) {
      Sentry.init { options =>
        options.setDsn(dsn)
        options.setEnvironment(sys.env.getOrElse("SENTRY_ENVIRONMENT", Environment.current.name))
        sys.env.get("SENTRY_RELEASE").filter(_.nonEmpty).foreach(options.setRelease)
        // Traces are not needed for plain error tracking; keep them off to avoid quota use.
        options.setTracesSampleRate(0.0d)
      }
    }
  }

  /** Report a Throwable to Sentry. No-op when Sentry was not initialised (no DSN). */
  def capture(t: Throwable): Unit =
    if (Sentry.isEnabled) { Sentry.captureException(t); () }
}
