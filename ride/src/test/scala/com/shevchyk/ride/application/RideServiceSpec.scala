package com.shevchyk.ride.application

import com.shevchyk.core.domain.*
import com.shevchyk.repository.{PersonRepository, MockPersonRepository}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.repository.InMemoryRideRepository
import zio.test.*
import zio.*
import java.util.UUID

object RideServiceSpec extends ZIOSpecDefault {

  def spec = suite("RideService")(
    suite("getRideById")(
      test("should return RideNotFound error for any ID") {
        for {
          service <- ZIO.service[RideService]
          result  <- service.getRideById(RideId(UUID.fromString("0000007b-0000-0000-0000-000000000123"))).exit
        } yield assertTrue(result.isFailure)
      }.provide(
        InMemoryRideRepository.layer,
        ZLayer.succeed[PersonRepository](MockPersonRepository()),
        RideService.layer
      )
    ),

    suite("createRide")(
      test("should create ride with generated ID") {
        val request = CreateRideRequest(
          clientId = PersonId(UUID.fromString("00000064-0000-0000-0000-000000000100")),
          pickupLocation = Location("Start Point"),
          dropoffLocation = Location("End Point"),
          notes = Some("Test ride")
        )

        for {
          service <- ZIO.service[RideService]
          ride    <- service.createRide(request)
        } yield assertTrue(
          ride.clientId == request.clientId &&
          ride.pickupLocation == request.pickupLocation &&
          ride.dropoffLocation == request.dropoffLocation &&
          ride.notes == request.notes &&
          ride.status == RideStatus.Requested
        )
      }.provide(
        InMemoryRideRepository.layer,
        ZLayer.succeed[PersonRepository](MockPersonRepository()),
        RideService.layer
      ),

      test("should create airport transfer ride") {
        val request = CreateRideRequest(
          clientId = PersonId(UUID.fromString("000000c8-0000-0000-0000-000000000200")),
          pickupLocation = Location("Airport Terminal 1"),
          dropoffLocation = Location("Hotel"),
          specifics = Some(RideSpecifics.AirportTransfer("KBP", "PS123"))
        )

        for {
          service <- ZIO.service[RideService]
          ride    <- service.createRide(request)
        } yield assertTrue(
          ride.isAirportTransfer &&
          ride.specifics.exists {
            case RideSpecifics.AirportTransfer(code, flight) =>
              code == "KBP" && flight == "PS123"
          }
        )
      }.provide(
        InMemoryRideRepository.layer,
        ZLayer.succeed[PersonRepository](MockPersonRepository()),
        RideService.layer
      )
    )
  )
}