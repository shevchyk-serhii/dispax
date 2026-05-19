package com.shevchyk.notification.application

import com.shevchyk.core.application.{EmailSmsService, RideConfirmationData}
import com.shevchyk.notification.domain.MessageTemplates
import zio.*
import zio.test.*

import java.time.Instant

object MessageTemplatesSpec extends ZIOSpecDefault {

  private val baseData = RideConfirmationData(
    rideId = "ride-123",
    clientName = "Anna Schmidt",
    pickupAddress = "Marienplatz 1",
    dropoffAddress = "Munich Airport"
  )

  def spec = suite("MessageTemplates")(

    suite("rideConfirmationText")(
      test("includes client name, pickup, dropoff and rideId") {
        val text = MessageTemplates.rideConfirmationText(baseData)
        assertTrue(
          text.contains("Anna Schmidt") &&
          text.contains("Marienplatz 1") &&
          text.contains("Munich Airport") &&
          text.contains("ride-123")
        )
      },

      test("omits scheduled time when not provided") {
        val text = MessageTemplates.rideConfirmationText(baseData)
        assertTrue(!text.contains("scheduled for"))
      },

      test("includes scheduled time when provided") {
        val t    = Instant.parse("2026-12-01T10:00:00Z")
        val text = MessageTemplates.rideConfirmationText(baseData.copy(scheduledTime = Some(t)))
        assertTrue(text.contains("scheduled for"))
      },

      test("includes estimated price when provided") {
        val text = MessageTemplates.rideConfirmationText(baseData.copy(estimatedPrice = Some(BigDecimal(49.99))))
        assertTrue(text.contains("49.99"))
      },

      test("omits price when not provided") {
        val text = MessageTemplates.rideConfirmationText(baseData)
        assertTrue(!text.contains("Estimated price"))
      }
    ),

    suite("driverAssignmentText")(
      test("uses provided driver name") {
        val text = MessageTemplates.driverAssignmentText(baseData.copy(driverName = Some("Max Müller")))
        assertTrue(text.contains("Max Müller"))
      },

      test("falls back to 'a driver' when driverName is None") {
        val text = MessageTemplates.driverAssignmentText(baseData)
        assertTrue(text.contains("a driver"))
      },

      test("includes client name, pickup and dropoff") {
        val text = MessageTemplates.driverAssignmentText(baseData.copy(driverName = Some("Hans")))
        assertTrue(
          text.contains("Anna Schmidt") &&
          text.contains("Marienplatz 1") &&
          text.contains("Munich Airport")
        )
      }
    ),

    suite("LoggingEmailSmsService")(
      test("sendRideConfirmation completes without error") {
        val svc = new LoggingEmailSmsService
        svc.sendRideConfirmation(baseData).as(assertCompletes)
      },

      test("sendDriverAssignment completes without error") {
        val svc = new LoggingEmailSmsService
        svc.sendDriverAssignment(baseData).as(assertCompletes)
      }
    )
  )
}
