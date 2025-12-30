package com.shevchyk.ride.infrastructure.http

import com.shevchyk.TestDataGenerator
import zio.*
import zio.http.*

object MockRideRoutes {

  private lazy val mockRides = TestDataGenerator.generateRides(count = 100)

  private val mockArrivals = """[
    {
      "icao24": "4B1814",
      "firstSeen": 1734089240,
      "estDepartureAirport": "EDDF",
      "lastSeen": 1734092840,
      "estArrivalAirport": "EDDM",
      "callsign": "DLH123"
    },
    {
      "icao24": "4B1815",
      "firstSeen": 1734087440,
      "estDepartureAirport": "EHAM",
      "lastSeen": 1734091040,
      "estArrivalAirport": "EDDM",
      "callsign": "KLM456"
    }
  ]"""

  private val mockDepartures = """[
    {
      "icao24": "4B1816",
      "firstSeen": 1734094640,
      "estDepartureAirport": "EDDM",
      "lastSeen": 1734098240,
      "estArrivalAirport": "EDDF",
      "callsign": "DLH789"
    },
    {
      "icao24": "4B1817",
      "firstSeen": 1734096440,
      "estDepartureAirport": "EDDM",
      "lastSeen": 1734100040,
      "estArrivalAirport": "EHAM",
      "callsign": "KLM321"
    }
  ]"""

  private val mockAirportTiming = """{
    "optimalEntryTime": "2025-12-11T14:30:00Z",
    "recommendedArrival": "2025-12-11T14:00:00Z",
    "terminalWalkTime": 15,
    "securityWaitTime": 20,
    "gateDistance": 8,
    "notes": "Terminal 2, Gate B3 - Allow extra time for security during peak hours"
  }"""

  val routes: Routes[Any, Response] = Routes(
    Method.GET / "api" / "v2" / "health"                               -> handler { (_: Request) =>
      ZIO.succeed(Response.text("Ride service is healthy"))
    },
    Method.GET / "api" / "rides" / "mock"                              -> handler { (_: Request) =>
      ZIO.succeed(Response.json(mockRides))
    },
    Method.GET / "api" / "flights" / string("airport") / "arrivals"    -> handler { (airport: String, _: Request) =>
      ZIO.succeed(Response.json(mockArrivals))
    },
    Method.GET / "api" / "flights" / string("airport") / "departures"  -> handler { (airport: String, _: Request) =>
      ZIO.succeed(Response.json(mockDepartures))
    },
    Method.GET / "api" / "airport" / "timing"                          -> handler { (request: Request) =>
      ZIO.succeed(Response.json(mockAirportTiming))
    },
    Method.GET / "api" / "airport" / "timing" / string("flightNumber") -> handler {
      (flightNumber: String, _: Request) =>
        ZIO.succeed(Response.json(mockAirportTiming))
    }
  )
}
