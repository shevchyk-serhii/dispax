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
    scheduledTime = request.scheduledTime,
    requestTime = Instant.now(),
    notes = request.notes,
    specifics = request.specifics,
    specialRequirements = request.specialRequirements
  )
