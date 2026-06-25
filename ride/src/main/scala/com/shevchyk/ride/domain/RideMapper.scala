package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import java.time.Instant

object RideMapper:

  def fromRequest(request: CreateRideRequest): Ride = Ride(
    id = RideId.generate(),
    clientId = request.clientId,
    creatorId = request.clientId,
    companyId = request.companyId,
    pickupLocation = request.pickupLocation,
    dropoffLocation = request.dropoffLocation,
    // pickupDateTime takes precedence over scheduledTime (which is the flight time for departures).
    // PickupTimeService fills in request.pickupDateTime before RideMapper is called for departure rides.
    pickupDateTime = request.pickupDateTime.orElse(request.scheduledTime).getOrElse(Instant.now()),
    scheduledTime = request.scheduledTime,
    requestTime = Instant.now(),
    // Carry the client/operator-supplied fare estimate through to the ride (None leaves it unpriced).
    estimatedPrice = request.estimatedPrice,
    notes = request.notes,
    specifics = request.specifics,
    specialRequirements = request.specialRequirements,
    vehicleClass = request.vehicleClass,
    // Operator-selected payment method carried from the create request (None leaves it unset).
    paymentMethod = request.paymentMethod
  )
