package com.shevchyk.app.routes

import zio.*
import zio.http.*
import zio.test.*

/**
 * Regression test for the WebSocket server-side heartbeat.
 *
 * Bug context: the WebSocket handler sent no Ping frames and the server used Netty's default read timeout (~60s). An
 * idle connection (no events flowing) was therefore torn down by the read timeout, causing clients to flap-reconnect
 * every minute. The fix adds a periodic Ping (`heartbeatLoop`) that keeps the connection non-idle.
 *
 * These tests exercise `heartbeatLoop` directly against a captured `send` function, driven by `TestClock`, so no real
 * WebSocketChannel / network is needed.
 */
object WebSocketHeartbeatSpec extends ZIOSpecDefault:

  def spec =
    suite("WebSocketRoutes.heartbeatLoop")(
      test("emits a Ping immediately, then one more per HEARTBEAT_INTERVAL") {
        for
          sent     <- Ref.make(List.empty[WebSocketFrame])
          fiber    <- WebSocketRoutes.heartbeatLoop(frame => sent.update(frame :: _)).fork
          // First ping fires right away so the socket is active from the start; wait for it
          // deterministically rather than reading the Ref before the forked fiber has run.
          initial  <- sent.get.repeatUntil(_.nonEmpty)
          // One additional ping per elapsed interval.
          _        <- TestClock.adjust(WebSocketRoutes.HEARTBEAT_INTERVAL)
          afterOne <- sent.get.repeatUntil(_.length >= 2)
          _        <- TestClock.adjust(WebSocketRoutes.HEARTBEAT_INTERVAL)
          _        <- TestClock.adjust(WebSocketRoutes.HEARTBEAT_INTERVAL)
          all      <- sent.get.repeatUntil(_.length >= 4)
          _        <- fiber.interrupt
        yield assertTrue(
          initial.length == 1,                 // immediate first ping
          afterOne.length == 2,                // +1 after one interval
          all.length == 4,                     // 1 immediate + 3 intervals
          all.forall(_ == WebSocketFrame.ping) // every frame is a Ping
        )
      },
      test("keeps sending pings as long as the fiber lives (does not stop after one)") {
        for
          count <- Ref.make(0)
          fiber <- WebSocketRoutes.heartbeatLoop(_ => count.update(_ + 1)).fork
          _     <- TestClock.adjust(WebSocketRoutes.HEARTBEAT_INTERVAL * 5)
          n     <- count.get.repeatUntil(_ >= 6)
          _     <- fiber.interrupt
        yield assertTrue(n == 6) // 1 immediate + 5 intervals
      },
      test("a failing send does not crash the loop — it keeps pinging") {
        for
          count <- Ref.make(0)
          // Every send fails; `.ignore` inside heartbeatLoop must swallow it and keep going.
          fiber <-
            WebSocketRoutes
              .heartbeatLoop(_ => count.update(_ + 1) *> ZIO.fail(new RuntimeException("boom")))
              .fork
          _     <- TestClock.adjust(WebSocketRoutes.HEARTBEAT_INTERVAL * 3)
          n     <- count.get.repeatUntil(_ >= 4)
          _     <- fiber.interrupt
        yield assertTrue(n == 4) // 1 immediate + 3 intervals, none crashed the loop
      }
    )
