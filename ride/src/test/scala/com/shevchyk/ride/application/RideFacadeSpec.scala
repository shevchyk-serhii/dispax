package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.*
import com.shevchyk.ride.repository.InMemoryRideRepository
import zio.test.*
import zio.*

object RideFacadeSpec extends ZIOSpecDefault {

  def spec = suite("RideFacade")(
    suite("createRide")(
      test("should successfully create a ride") {
        val request = CreateRideRequest(
          clientId = PersonId(100),
          pickupLocation = Location("Pickup Address"),
          dropoffLocation = Location("Dropoff Address")
        )

        for {
          facade <- ZIO.service[RideFacade]
          ride   <- facade.createRide(request)
        } yield assertTrue(
          ride.clientId == request.clientId &&
          ride.pickupLocation == request.pickupLocation &&
          ride.dropoffLocation == request.dropoffLocation &&
          ride.status == RideStatus.Requested
        )
      }.provide(
        InMemoryRideRepository.layer,
        RideCreationService.layer,
        SimpleRideService.layer,
        RideFacade.layer
      )
    ),

    suite("getRideById")(
      test("should return failure for non-existing ride") {
        for {
          facade <- ZIO.service[RideFacade]
          result <- facade.getRideById(RideId(999)).exit
        } yield assertTrue(result.isFailure)
      }.provide(
        InMemoryRideRepository.layer,
        RideCreationService.layer,
        SimpleRideService.layer,
        RideFacade.layer
      )
    )
  )
}