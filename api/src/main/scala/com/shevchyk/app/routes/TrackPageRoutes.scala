package com.shevchyk.app.routes

import com.shevchyk.core.config.MapboxConfig
import zio.*
import zio.http.*

/**
 * Server-rendered public guest tracking page.
 *
 * `GET /track/{token}` returns a self-contained HTML document (Mapbox GL JS + a little vanilla JS) that a browser-only
 * client opens from a share link — no app, no login. The page fetches `GET /api/track/{token}` for the initial ride
 * state and opens the guest WebSocket `GET /api/ws/track?token=` for live driver-position updates. It deliberately
 * shows NO driver/client PII and no price (the public API already strips those).
 *
 * This replaces the earlier Flutter-web guest screen, which could not render: `mapbox_maps_flutter` is unsupported on
 * web (its initializer crashes the web compiler). Mapbox GL JS is the real browser map SDK and works everywhere.
 *
 * The page is a thin shell: it does NOT resolve the token server-side. An invalid/expired token simply makes the
 * client-side `fetch` return 404, which the JS renders as a friendly "link expired" state — no existence leak, and no
 * duplicated validation logic.
 */
object TrackPageRoutes:

  // Supported UI languages; German is the default (the MVP targets Munich).
  private val supportedLangs = Set("de", "en", "uk")
  private val defaultLang    = "de"

  /**
   * Pick the page language: explicit `?lang=` wins, else the first supported language in `Accept-Language`, else the
   * default. Package-private for unit testing without an HTTP server.
   */
  private[app] def selectLang(langParam: Option[String], acceptLanguage: Option[String]): String = langParam
    .map(_.toLowerCase)
    .filter(supportedLangs.contains)
    .orElse {
      acceptLanguage.flatMap { header =>
        // "de-DE,de;q=0.9,en;q=0.8" -> first 2-letter tag we support
        header
          .split(",")
          .iterator
          .map(_.trim.takeWhile(c => c != ';' && c != '-').toLowerCase)
          .find(supportedLangs.contains)
      }
    }
    .getOrElse(defaultLang)

  // Share tokens are URL-safe Base64 (see RideShareToken.generateTokenValue). Reject anything else outright — a
  // defence-in-depth guard so a hostile path segment never reaches the HTML template, on top of JS-string escaping.
  private val tokenPattern = "^[A-Za-z0-9_-]{1,128}$".r

  val routes: Routes[MapboxConfig, Response] = Routes(
    Method.GET / "track" / string("token") -> handler { (token: String, req: Request) =>
      if !tokenPattern.matches(token) then ZIO.succeed(Response.status(Status.NotFound))
      else
        val langParam      = req.url.queryParams.queryParam("lang")
        val acceptLanguage = req.headers.get(Header.AcceptLanguage).map(_.renderedValue)
        val lang           = selectLang(langParam, acceptLanguage)
        ZIO.serviceWith[MapboxConfig] { mapbox =>
          Response(
            Status.Ok,
            Headers(Header.ContentType(MediaType.text.html)),
            Body.fromString(GuestTrackingPage.render(token, lang, mapbox.accessToken))
          )
        }
    }
  )
