package com.shevchyk

import zio.http.*
import zio.test.*

/**
 * Guards the server's request body-size limit. zio-http's `Server.Config.default` caps the body at 100 KB and rejects
 * anything larger with a 413 at the Netty layer — before the request reaches the avatar endpoint. That is smaller than
 * the 5 MB profile-photo limit `AvatarService` enforces, so avatar uploads failed with 413. The server must accept
 * bodies above 5 MB (+ multipart overhead) for the app-level limit to be the one that actually applies.
 *
 * This asserts the configured limit directly (no server boot needed): a service-layer test would never reach Netty's
 * cap, so only this kind of assertion locks the fix in. Mutation check: revert `serverConfig` to
 * `Server.Config.default` and this goes red.
 */
object ApplicationSpec extends ZIOSpecDefault:

  def spec =
    suite("ApplicationSpec")(
      test("server accepts request bodies large enough for a 5 MB avatar") {
        val limit =
          Application.serverConfig("0.0.0.0", 8080).requestStreaming match
            case Server.RequestStreaming.Disabled(maxLength) => maxLength
            case _                                           => -1 // streaming enabled / unexpected → fail the assertion
        assertTrue(
          Application.MaxRequestBytes >= 5 * 1024 * 1024, // above the AvatarService 5 MB cap
          limit == Application.MaxRequestBytes // and that limit is what the server is actually configured with
        )
      }
    )
