package com.shevchyk.app.openapi

import java.util.UUID

import zio.{Task, ZIO, ZLayer}

import com.shevchyk.ride.application.service.AirportConfigService
import com.shevchyk.ride.domain.{Airport, AirportCheckpoint, AirportCheckpointZone}

/**
 * Minimal [[AirportConfigService]] double for the checkpoint endpoint specs. The only method the real
 * `AirportCheckpointService.markCheckpoint` reaches is `getCheckpointDisplayName`, and it is already wrapped in a
 * `.catchAll` that falls back to the enum name — so this returns that fallback via the **typed-success** channel (never
 * `ZIO.die`, which would escape the `.catchAll` and crash the test). Every other method dies loudly.
 */
object StubAirportConfigService:

  val layer: ZLayer[Any, Nothing, AirportConfigService] = ZLayer.succeed(new AirportConfigService:
    private def notImpl(m: String): Nothing = throw new NotImplementedError(s"StubAirportConfigService.$m")

    def getCheckpointDisplayName(airportCode: String, checkpoint: AirportCheckpoint): Task[String] = ZIO.succeed(
      AirportCheckpoint.defaultDisplayName(checkpoint)
    )

    def listAirports(): Task[List[Airport]]                                                    = notImpl("listAirports")
    def getAirport(code: String): Task[Option[Airport]]                                        = notImpl("getAirport")
    def createAirport(airport: Airport): Task[Airport]                                         = notImpl("createAirport")
    def updateAirport(code: String, airport: Airport): Task[Option[Airport]]                   = notImpl("updateAirport")
    def deleteAirport(code: String): Task[Boolean]                                             = notImpl("deleteAirport")
    def createZone(zone: AirportCheckpointZone): Task[AirportCheckpointZone]                   = notImpl("createZone")
    def updateZone(id: UUID, zone: AirportCheckpointZone): Task[Option[AirportCheckpointZone]] = notImpl("updateZone")
    def deleteZone(id: UUID): Task[Boolean]                                                    = notImpl("deleteZone")
    def getLandingGeofence(airportCode: String): Task[Option[(Double, Double, Int)]]           = notImpl("getLandingGeofence")
  )
