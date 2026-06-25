package com.shevchyk.core.config

import zio.*

/**
 * Base URL under which the app is reachable from the public internet, used to build absolute share links
 * (`<baseUrl>/track/<token>`) that work for any client — including non-browser ones (SMS, mobile, external services)
 * that have no notion of the current page origin.
 *
 * Read from `PUBLIC_BASE_URL` (e.g. `https://dispax-o2trzxjbva-ew.a.run.app` in prod, `http://localhost:8080` in dev).
 * Empty when unset — callers then fall back to returning the relative path so nothing breaks.
 */
case class PublicLinkConfig(baseUrl: String):

  /**
   * Build a shareable URL for a relative `path` (which always starts with `/`). Returns the path unchanged when no base
   * URL is configured, and trims a trailing slash on the base so we never emit `//track`.
   */
  def absoluteUrl(path: String): String =
    if baseUrl.isEmpty then path
    else baseUrl.stripSuffix("/") + path

object PublicLinkConfig:

  val liveLayer: ZLayer[Any, Nothing, PublicLinkConfig] = ZLayer.succeed(
    PublicLinkConfig(baseUrl = sys.env.getOrElse("PUBLIC_BASE_URL", ""))
  )
