package com.shevchyk.service

import zio.*
import zio.json.*
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.net.URI

case class FlightData(
    icao24: String,
    firstSeen: Long,
    estDepartureAirport: String,
    lastSeen: Long,
    estArrivalAirport: String,
    callsign: String
)

object FlightData:
  given JsonDecoder[FlightData] = DeriveJsonDecoder.gen
  given JsonEncoder[FlightData] = DeriveJsonEncoder.gen

trait FlightService:
  def getMunichArrivals(beginTime: Long, endTime: Long): Task[List[FlightData]]
  def getMunichDepartures(beginTime: Long, endTime: Long): Task[List[FlightData]]

class FlightServiceImpl extends FlightService:
  private val munichIcao = "EDDM"
  private val baseUrl    = "https://opensky-network.org/api"

  override def getMunichArrivals(beginTime: Long, endTime: Long): Task[List[FlightData]] =
    val url = s"$baseUrl/flights/arrival?airport=$munichIcao&begin=$beginTime&end=$endTime"
    makeRequest(url).catchAll { error =>
      ZIO.logWarning(s"OpenSky API failed, using mock data: ${error.getMessage}") *>
        getMockArrivals(beginTime, endTime)
    }

  override def getMunichDepartures(beginTime: Long, endTime: Long): Task[List[FlightData]] =
    val url = s"$baseUrl/flights/departure?airport=$munichIcao&begin=$beginTime&end=$endTime"
    makeRequest(url).catchAll { error =>
      ZIO.logWarning(s"OpenSky API failed, using mock data: ${error.getMessage}") *>
        getMockDepartures(beginTime, endTime)
    }

  private def makeRequest(url: String): Task[List[FlightData]] = ZIO.attemptBlocking {
    val client  = HttpClient.newHttpClient()
    val request = HttpRequest
      .newBuilder()
      .uri(URI.create(url))
      .build()

    val response = client.send(request, HttpResponse.BodyHandlers.ofString())

    if (response.statusCode() != 200) {
      throw new RuntimeException(s"HTTP ${response.statusCode()}")
    }

    val body = response.body()
    body.fromJson[List[FlightData]] match {
      case Right(flights) => flights
      case Left(error)    => throw new RuntimeException(s"JSON decode error: $error")
    }
  }

  private def getMockArrivals(beginTime: Long, endTime: Long): Task[List[FlightData]] = ZIO.succeed(
    List(
      FlightData("abc123", beginTime, "EDDF", beginTime + 3600, "EDDM", "LH123 "),
      FlightData("def456", beginTime + 1800, "EGLL", beginTime + 5400, "EDDM", "BA456 "),
      FlightData("ghi789", beginTime + 2700, "LFPG", beginTime + 6300, "EDDM", "AF789 ")
    )
  )

  private def getMockDepartures(beginTime: Long, endTime: Long): Task[List[FlightData]] = ZIO.succeed(
    List(
      FlightData("xyz987", beginTime, "EDDM", beginTime + 3600, "KJFK", "LH654 "),
      FlightData("uvw321", beginTime + 900, "EDDM", beginTime + 4500, "EGLL", "BA987 "),
      FlightData("rst654", beginTime + 1800, "EDDM", beginTime + 5400, "LFPG", "AF321 ")
    )
  )

object FlightService:
  val live: ULayer[FlightService] = ZLayer.succeed(FlightServiceImpl())
