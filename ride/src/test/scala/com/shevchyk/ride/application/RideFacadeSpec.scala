package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.repository.{PersonRepository, MockPersonRepository}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.repository.InMemoryRideRepository
import zio.test.*
import zio.*
import java.util.UUID

object RideFacadeSpec extends ZIOSpecDefault {

  def spec = suite("RideFacade")(
    suite("createRide")(
      test("should successfully create a ride") {
        val request = CreateRideRequest(
          clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          companyId = CompanyId(UUID.fromString("11111111-1111-1111-1111-111111111111")),
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
        ZLayer.succeed[PersonRepository](MockPersonRepository()),
        RideService.layer,
        RideFacade.layer
      )
    ),

    suite("getRideById")(
      test("should return failure for non-existing ride") {
        for {
          facade <- ZIO.service[RideFacade]
          result <- facade.getRideById(RideId(UUID.fromString("000003e7-0000-0000-0000-000000000999"))).exit
        } yield assertTrue(result.isFailure)
      }.provide(
        InMemoryRideRepository.layer,
        ZLayer.succeed[PersonRepository](MockPersonRepository()),
        RideService.layer,
        RideFacade.layer
      )
    )
  )
}