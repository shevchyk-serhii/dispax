package com.shevchyk.core.config

import zio.test.*

object PublicLinkConfigSpec extends ZIOSpecDefault:

  def spec =
    suite("PublicLinkConfig.absoluteUrl")(
      test("prefixes the base URL onto the path") {
        val c = PublicLinkConfig("https://dispax.example")
        assertTrue(c.absoluteUrl("/track/abc") == "https://dispax.example/track/abc")
      },
      test("trims a trailing slash on the base so there is no double slash") {
        val c = PublicLinkConfig("https://dispax.example/")
        assertTrue(c.absoluteUrl("/track/abc") == "https://dispax.example/track/abc")
      },
      test("falls back to the relative path when no base URL is configured") {
        val c = PublicLinkConfig("")
        assertTrue(c.absoluteUrl("/track/abc") == "/track/abc")
      }
    )
