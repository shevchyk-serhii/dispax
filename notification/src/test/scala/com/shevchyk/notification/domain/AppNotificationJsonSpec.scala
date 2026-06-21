package com.shevchyk.notification.domain

import com.shevchyk.core.domain.{CompanyId, PersonId}
import zio.json.*
import zio.json.ast.Json
import zio.test.*

import java.time.Instant
import java.util.UUID

/**
 * Regression for the Flutter notifications screen crash
 * `type '_Map<String, dynamic>' is not a subtype of type 'String'`.
 *
 * Root cause: `AppNotificationId` derived its JsonCodec, serializing as an object
 * `{"value":"uuid"}` instead of the flat string the clients expect (like
 * `PersonId`/`CompanyId`). The client read `id` as a plain String and crashed.
 */
object AppNotificationJsonSpec extends ZIOSpecDefault {

  private val id        = AppNotificationId(UUID.fromString("00000000-0000-0000-0000-0000000000aa"))
  private val personId  = PersonId(UUID.fromString("00000000-0000-0000-0000-0000000000bb"))
  private val companyId = CompanyId(UUID.fromString("00000000-0000-0000-0000-0000000000cc"))

  private val sample = AppNotification(
    id = id,
    personId = personId,
    companyId = companyId,
    title = "New ride",
    body = "A ride was assigned",
    notificationType = "ride_assigned",
    data = Some("""{"rideId":"x"}"""),
    isRead = false,
    createdAt = Instant.parse("2026-06-21T18:07:00Z")
  )

  def spec = suite("AppNotification JSON")(
    test("id serializes as a flat string, not an object") {
      val ast = sample.toJsonAST.toOption.get
      val idField = ast.asObject.flatMap(_.get("id")).get
      assertTrue(idField == Json.Str(id.value.toString))
    },
    test("the id field is never a nested object") {
      val ast = sample.toJsonAST.toOption.get
      val idField = ast.asObject.flatMap(_.get("id")).get
      assertTrue(idField.asObject.isEmpty)
    },
    test("round-trips through JSON") {
      val decoded = sample.toJson.fromJson[AppNotification]
      assertTrue(decoded == Right(sample))
    },
    test("decodes an id given as a flat string") {
      val json =
        s"""{"id":"${id.value}","personId":"${personId.value}","companyId":"${companyId.value}",
           |"title":"t","body":"b","notificationType":"ride_assigned","data":null,
           |"isRead":false,"createdAt":"2026-06-21T18:07:00Z"}""".stripMargin
      val decoded = json.fromJson[AppNotification]
      assertTrue(decoded.map(_.id) == Right(id))
    }
  )
}
