package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.*
import zio.test.*
import zio.*

object SimpleRideServiceSpec extends ZIOSpecDefault {

  def spec = suite("SimpleRideService")(
    suite("getRideById")(
      test("should return RideNotFound error for any ID") {
        for {
          service <- ZIO.service[SimpleRideService]
          result  <- service.getRideById(RideId(123)).exit
        } yield assertTrue(result.isFailure)
      }.provide(SimpleRideService.layer)
    ),

    suite("createRide")(
      test("should create ride with generated ID") {
        val request = CreateRideRequest(
          clientId = PersonId(100),
          pickupLocation = Location("Start Point"),
          dropoffLocation = Location("End Point"),
          notes = Some("Test ride")
        )

        for {
          service <- ZIO.service[SimpleRideService]
          ride    <- service.createRide(request)
        } yield assertTrue(
          ride.clientId == request.clientId &&
          ride.pickupLocation == request.pickupLocation &&
          ride.dropoffLocation == request.dropoffLocation &&
          ride.notes == request.notes &&
          ride.status == RideStatus.Requested
        )
      }.provide(SimpleRideService.layer),

      test("should create airport transfer ride") {
        val request = CreateRideRequest(
          clientId = PersonId(200),
          pickupLocation = Location("Airport Terminal 1"),
          dropoffLocation = Location("Hotel"),
          airportCode = Some("KBP"),
          flightNumber = Some("PS123"),
          isAirportTransfer = true
        )

        for {
          service <- ZIO.service[SimpleRideService]
          ride    <- service.createRide(request)
        } yield assertTrue(
          ride.isAirportTransfer &&
          ride.airportCode.contains("KBP") &&
          ride.flightNumber.contains("PS123")
        )
      }.provide(SimpleRideService.layer)
    )
  )
}