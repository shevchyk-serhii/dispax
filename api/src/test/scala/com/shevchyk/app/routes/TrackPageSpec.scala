package com.shevchyk.app.routes

import zio.test.*

/**
 * Guards the server-rendered guest tracking page: language selection (?lang= / Accept-Language / default) and the HTML
 * template (token embedded, correct lang, localized strings, no script-injection escape hatch). Pure functions, no HTTP
 * server needed.
 */
object TrackPageSpec extends ZIOSpecDefault:

  def spec =
    suite("TrackPageSpec")(
      suite("selectLang")(
        test("?lang= wins when supported") {
          assertTrue(TrackPageRoutes.selectLang(Some("uk"), Some("de-DE,de;q=0.9")) == "uk")
        },
        test("unsupported ?lang= falls through to Accept-Language") {
          assertTrue(TrackPageRoutes.selectLang(Some("fr"), Some("en-US,en;q=0.9")) == "en")
        },
        test("Accept-Language picks the first supported tag") {
          assertTrue(TrackPageRoutes.selectLang(None, Some("fr-FR,de;q=0.8,en;q=0.7")) == "de")
        },
        test("defaults to de when nothing matches") {
          assertTrue(
            TrackPageRoutes.selectLang(None, None) == "de",
            TrackPageRoutes.selectLang(None, Some("fr-FR,es;q=0.8")) == "de"
          )
        }
      ),
      suite("GuestTrackingPage.render")(
        test("embeds the token and selected language, and localizes the title") {
          val html = GuestTrackingPage.render("tok-ABC_123", "en", "pk.test")
          assertTrue(
            html.startsWith("<!DOCTYPE html>"),
            html.contains("<html lang=\"en\">"),
            html.contains("tok-ABC_123"),     // token reachable by the page JS
            html.contains("Track your ride"), // EN title
            html.contains("pk.test"),         // mapbox token embedded
            html.contains("/api/ws/track?token=")
          )
        },
        test("German is used for de and for an unknown language") {
          val de = GuestTrackingPage.render("t", "de", "")
          val xx = GuestTrackingPage.render("t", "zz", "")
          assertTrue(
            de.contains("Fahrt verfolgen"),
            xx.contains("Fahrt verfolgen"), // unknown -> de fallback
            xx.contains("<html lang=\"de\">")
          )
        },
        test("a hostile token cannot break out of the JS string literal") {
          // The </script> and quote chars must be neutralized so they can't terminate the inline script.
          val html = GuestTrackingPage.render("a'</script><b>", "en", "")
          assertTrue(
            !html.contains("</script><b>"), // raw breakout sequence must not appear
            !html.contains("a'</")          // unescaped quote+tag must not appear
          )
        }
      )
    )
