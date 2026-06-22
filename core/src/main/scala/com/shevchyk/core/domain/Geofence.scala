package com.shevchyk.core.domain

import zio.json.*
import java.time.Instant
import java.util.UUID
import com.github.f4b6a3.uuid.UuidCreator

case class GeofenceId(value: UUID)

object GeofenceId:
  def generate(): GeofenceId  = GeofenceId(UuidCreator.getTimeOrderedEpoch())
  given JsonCodec[GeofenceId] = JsonCodec[UUID].transform(GeofenceId(_), _.value)

enum GeofenceType derives JsonCodec:
  case Airport, ServiceArea, ClientPickup, CustomZone

final case class Geofence(
    id: GeofenceId,
    companyId: CompanyId,
    name: String,
    geofenceType: GeofenceType,
    centerLatitude: Double,
    centerLongitude: Double,
    radiusMeters: Int,
    isActive: Boolean = true,
    notifyOnEntry: Boolean = true,
    notifyOnExit: Boolean = false,
    createdAt: Instant = Instant.now()
) derives JsonCodec

final case class CreateGeofenceRequest(
    name: String,
    geofenceType: String,
    centerLatitude: Double,
    centerLongitude: Double,
    radiusMeters: Int,
    notifyOnEntry: Boolean = true,
    notifyOnExit: Boolean = false
) derives JsonCodec

final case class GeofenceAlert(
    id: UUID,
    geofenceId: GeofenceId,
    driverId: PersonId,
    companyId: CompanyId,
    alertType: String, // "entry" or "exit"
    geofenceName: String,
    latitude: Double,
    longitude: Double,
    timestamp: Instant = Instant.now()
) derives JsonCodec
