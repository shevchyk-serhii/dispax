package com.shevchyk.app.routes

import com.shevchyk.core.domain.PersonRole
import zio.test.*

import java.util.UUID

/**
 * CRITICAL — tenant filter of the authenticated event WebSocket (regression).
 *
 * The filter used to be `event.companyId == payload.companyId.getOrElse(event.companyId)`: a JWT WITHOUT a companyId
 * (SUPER_ADMIN, or a historically companyId-less account) made the condition compare the event with itself — always
 * true — so that socket received the event stream of EVERY tenant on the platform (fail-open). The filter must be
 * fail-closed: no companyId → nothing, unless the subscriber is a SuperAdmin (platform-wide monitoring is that role's
 * job).
 */
object AuthenticatedSocketTenantFilterSpec extends ZIOSpecDefault:

  private val companyA = UUID.fromString("00000005-0000-0000-0000-00000000000a")
  private val companyB = UUID.fromString("00000005-0000-0000-0000-00000000000b")

  def spec =
    suite("WebSocketRoutes.shouldDeliverToAuthenticated")(
      test("subscriber with a companyId receives own-company events only") {
        assertTrue(
          WebSocketRoutes.shouldDeliverToAuthenticated(companyA, Some(companyA), Set(PersonRole.Dispatcher)),
          !WebSocketRoutes.shouldDeliverToAuthenticated(companyB, Some(companyA), Set(PersonRole.Dispatcher))
        )
      },
      test("subscriber WITHOUT a companyId receives NOTHING (fail-closed) unless SuperAdmin") {
        assertTrue(
          !WebSocketRoutes.shouldDeliverToAuthenticated(companyA, None, Set(PersonRole.Dispatcher)),
          !WebSocketRoutes.shouldDeliverToAuthenticated(companyA, None, Set(PersonRole.Client)),
          !WebSocketRoutes.shouldDeliverToAuthenticated(companyA, None, Set.empty)
        )
      },
      test("SuperAdmin without a companyId keeps the platform-wide stream") {
        assertTrue(
          WebSocketRoutes.shouldDeliverToAuthenticated(companyA, None, Set(PersonRole.SuperAdmin)),
          WebSocketRoutes.shouldDeliverToAuthenticated(companyB, None, Set(PersonRole.SuperAdmin))
        )
      }
    )
