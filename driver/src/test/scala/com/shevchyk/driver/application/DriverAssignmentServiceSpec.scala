package com.shevchyk.driver.application

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.test.*
import zio.*

object DriverAssignmentServiceSpec extends ZIOSpecDefault {

  def spec = suite("DriverAssignmentService")(
    suite("assignDriverToRide")(
      test("should return RideNotFound for any assignment request") {
        for {
          service <- ZIO.service[DriverAssignmentService]
          result  <- service.assignDriverToRide(RideId(1), PersonId(100)).exit
        } yield assertTrue(result.isFailure)
      }.provide(DriverAssignmentService.layer)
    )
  )
}