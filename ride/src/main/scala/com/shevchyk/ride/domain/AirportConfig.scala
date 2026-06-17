package com.shevchyk.ride.domain

import java.time.Instant
import java.util.UUID
import zio.json.*

/**
 * Domain case classes for the airport configuration feature.
 *
 * Airports are intentionally GLOBAL (no company_id). Access control is enforced at the HTTP layer via
 * `requireSuperAdmin(user)` in [[com.shevchyk.app.openapi.SuperAdminAirportApi]].
 */

final case class AirportCheckpointZone(
    id: UUID,
    airportCode: String,
    terminalCode: String,
    checkpointType: String, // raw DB string — matches AirportCheckpoint.toDbString
    displayName: String,
    lat: Double,
    lon: Double,
    radiusMeters: Int,
    sortOrder: Int,
    createdAt: Instant,
    updatedAt: Instant
) derives JsonCodec

final case class Airport(
    code: String,
    name: String,
    country: String,
    landingLat: Double,
    landingLon: Double,
    landingRadius: Int,
    isActive: Boolean,
    zones: List[AirportCheckpointZone] = Nil,
    createdAt: Instant,
    updatedAt: Instant
) derives JsonCodec
