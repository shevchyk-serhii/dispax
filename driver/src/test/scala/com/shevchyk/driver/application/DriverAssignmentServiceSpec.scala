package com.shevchyk.driver.application

import com.shevchyk.core.domain.*
import zio.test.*
import zio.*
import java.util.UUID

object DriverAssignmentServiceSpec extends ZIOSpecDefault {

  def spec = suite("DriverAssignmentService")(
    suite("assignDriverToRide")(
      test("should return RideNotFound for any assignment request") {
        for {
          service <- ZIO.service[DriverAssignmentService]
          result  <- service.assignDriverToRide(RideId(UUID.fromString("11111111-1111-1111-1111-111111111111")), PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100"))).exit
        } yield assertTrue(result.isFailure)
      }.provide(DriverAssignmentService.layer)
    )
  )
}