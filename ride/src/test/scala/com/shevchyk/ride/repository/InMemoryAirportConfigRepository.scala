package com.shevchyk.ride.repository

import com.shevchyk.ride.domain.{Airport, AirportCheckpointZone}
import zio.*

import java.util.UUID

/**
 * In-memory test double for [[AirportConfigRepository]].
 *
 * Follows the [[InMemoryRideRepository]] pattern: state is held in a [[Ref.Synchronized]] so tests
 * can call methods concurrently without race conditions. Used ONLY in unit tests — integration tests
 * use the real PostgreSQL implementation via Testcontainers (invariant §4).
 */
class InMemoryAirportConfigRepository extends AirportConfigRepository:

  private val state: Ref.Synchronized[Map[String, Airport]] =
    Unsafe.unsafe { implicit unsafe =>
      Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[String, Airport])).getOrThrowFiberFailure()
    }

  override def findAll(): Task[List[Airport]] =
    state.get.map(_.values.toList)

  override def findByCode(code: String): Task[Option[Airport]] =
    state.get.map(_.get(code))

  override def create(airport: Airport): Task[Airport] =
    state.update(_.updated(airport.code, airport)).as(airport)

  override def update(code: String, airport: Airport): Task[Option[Airport]] =
    state.get.flatMap { m =>
      if m.contains(code) then
        val updated = airport.copy(code = code)
        state.update(_.updated(code, updated)).as(Some(updated))
      else ZIO.succeed(None)
    }

  override def delete(code: String): Task[Boolean] =
    state.get.flatMap { m =>
      m.get(code) match
        case None          => ZIO.succeed(false)
        case Some(airport) =>
          if !airport.isActive then ZIO.succeed(false)
          else
            val softDeleted = airport.copy(isActive = false)
            state.update(_.updated(code, softDeleted)).as(true)
    }

  override def createZone(zone: AirportCheckpointZone): Task[AirportCheckpointZone] =
    state.get.flatMap { m =>
      m.get(zone.airportCode) match
        case None          =>
          ZIO.fail(new RuntimeException(s"Airport not found: ${zone.airportCode}"))
        case Some(airport) =>
          val zoneWithId = zone.copy(id = UUID.randomUUID())
          val updated    = airport.copy(zones = airport.zones :+ zoneWithId)
          state.update(_.updated(airport.code, updated)).as(zoneWithId)
    }

  override def updateZone(id: UUID, zone: AirportCheckpointZone): Task[Option[AirportCheckpointZone]] =
    state.get.flatMap { m =>
      val airportOpt = m.values.find(_.zones.exists(_.id == id))
      airportOpt match
        case None          => ZIO.succeed(None)
        case Some(airport) =>
          val updatedZone    = zone.copy(id = id, airportCode = airport.code)
          val updatedZones   = airport.zones.map(z => if z.id == id then updatedZone else z)
          val updatedAirport = airport.copy(zones = updatedZones)
          state.update(_.updated(airport.code, updatedAirport)).as(Some(updatedZone))
    }

  override def deleteZone(id: UUID): Task[Boolean] =
    state.get.flatMap { m =>
      val airportOpt = m.values.find(_.zones.exists(_.id == id))
      airportOpt match
        case None          => ZIO.succeed(false)
        case Some(airport) =>
          val updatedZones   = airport.zones.filterNot(_.id == id)
          val updatedAirport = airport.copy(zones = updatedZones)
          state.update(_.updated(airport.code, updatedAirport)).as(true)
    }
