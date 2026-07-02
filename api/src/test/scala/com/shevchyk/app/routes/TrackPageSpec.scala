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
        test("driver caption is localized") {
          assertTrue(
            GuestTrackingPage.render("t", "de", "").contains("Ihr Fahrer"),
            GuestTrackingPage.render("t", "en", "").contains("Your driver"),
            GuestTrackingPage.render("t", "uk", "").contains("Ваш водій")
          )
        },
        test("driver car icon + pulsing halo + shimmer are present") {
          val html = GuestTrackingPage.render("t", "en", "pk.test")
          assertTrue(
            html.contains("driver-marker"), // themed driver marker class
            html.contains("pulse-halo"),    // radar halo keyframes
            html.contains("shimmer"),       // gentle icon shimmer keyframes
            html.contains("SVG_CAR"),       // inline car icon
            html.contains("makeMarkerEl(SVG_CAR")
          )
        },
        test("pickup and dropoff are labeled icon markers") {
          val html = GuestTrackingPage.render("t", "en", "pk.test")
          assertTrue(
            html.contains("pickup-marker"),
            html.contains("dropoff-marker"),
            html.contains("makeMarkerEl(SVG_PERSON, 'pickup-marker', I.pickup"),
            html.contains("makeMarkerEl(SVG_FLAG, 'dropoff-marker', I.dropoff")
          )
        },
        test("airport self-report block: buttons, POST endpoint and forward-only guard are present") {
          val html = GuestTrackingPage.render("t", "en", "pk.test")
          assertTrue(
            html.contains("id=\"airport\""),            // self-report container
            html.contains("data-cp=\"landed\""),        // landed button
            html.contains("data-cp=\"arrivals_hall\""), // baggage button
            html.contains("data-cp=\"terminal_exit\""), // exit button
            html.contains("/checkpoint"),               // POST endpoint
            html.contains("'POST'"),                    // it is a POST
            html.contains("AirportCheckpointReached"),  // live WS handling
            html.contains("CP_ORDER")                   // forward-only ordering
          )
        },
        test("airport self-report labels are localized (de/en/uk)") {
          assertTrue(
            GuestTrackingPage.render("t", "de", "").contains("Am Ausgang"),
            GuestTrackingPage.render("t", "en", "").contains("At the exit"),
            GuestTrackingPage.render("t", "uk", "").contains("Біля виходу")
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
