package com.shevchyk.ride.infrastructure.http

import com.shevchyk.TestDataGenerator
import com.shevchyk.ride.domain.{*, given}
import com.shevchyk.ride.application.RideFacade
import com.shevchyk.ride.repository.RideRepository
import com.shevchyk.core.domain.{RideId, PersonId}
import java.util.UUID
import com.shevchyk.auth.middleware.{AuthMiddleware, AuthenticatedUser}
import com.shevchyk.auth.service.JwtService
import zio.*
import zio.http.*
import zio.json.*

object RideRoutes {
  import com.shevchyk.repository.PersonRepository

  // Generate rich test data with many rides and users
  private lazy val mockRides = TestDataGenerator.generateRides(count = 100)

  // Mock flight data for frontend compatibility
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

  // Mock airport timing data
  private val mockAirportTiming = """{
    "optimalEntryTime": "2025-12-11T14:30:00Z",
    "recommendedArrival": "2025-12-11T14:00:00Z",
    "terminalWalkTime": 15,
    "securityWaitTime": 20,
    "gateDistance": 8,
    "notes": "Terminal 2, Gate B3 - Allow extra time for security during peak hours"
  }"""

  // Simple routes for ride management (without complex auth for now)
  val authenticatedRoutes: Routes[RideFacade, Response] = Routes(
    // Create new ride
    Method.POST / "api" / "rides" -> handler { (request: Request) =>
      val createRideLogic =
        for {
          bodyStr      <- request.body.asString
          apiRequest   <- ZIO
                            .fromEither(bodyStr.fromJson[CreateRideApiRequest])
                            .mapError(_ => "Invalid JSON format")

          // For now, use hardcoded client ID (would come from JWT token in production)
          domainRequest = CreateRideApiRequest.toDomain(apiRequest).copy(clientId = PersonId.generate())
          facade       <- ZIO.service[RideFacade]
          ride         <- facade.createRide(domainRequest)
        } yield RideDto.fromDomain(ride)

      createRideLogic
        .map(rideDto => Response(Status.Created, body = Body.fromString(rideDto.toJson)))
        .catchAll {
          case msg: String                    => ZIO.succeed(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"$msg"}""")))
          case RideError.ValidationError(msg) =>
            ZIO.succeed(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"$msg"}""")))
          case RideError.DatabaseError(_)     =>
            ZIO.succeed(Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Database error"}""")))
          case _                              =>
            ZIO.succeed(
              Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}"""))
            )
        }
    },

    // Get rides for user
    Method.GET / "api" / "rides" -> handler { (_: Request) =>
      val getRidesLogic =
        for {
          facade <- ZIO.service[RideFacade]
          // For now, get rides for hardcoded user ID
          rides  <- facade.getRidesForUser(PersonId.generate())
        } yield rides.map(RideDto.fromDomain)

      getRidesLogic
        .map(rideDtos => Response.json(rideDtos.toJson))
        .catchAll(_ =>
          ZIO.succeed(
            Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Failed to fetch rides"}"""))
          )
        )
    },

    // Get specific ride by ID
    Method.GET / "api" / "rides" / string("rideId") -> handler { (rideId: String, _: Request) =>
      val getRideLogic =
        for {
          facade <- ZIO.service[RideFacade]
          ride   <- facade.getRideById(RideId(UUID.fromString(rideId)))
        } yield RideDto.fromDomain(ride)

      getRideLogic
        .map(rideDto => Response.json(rideDto.toJson))
        .catchAll {
          case RideError.RideNotFound(_) =>
            ZIO.succeed(Response(Status.NotFound, body = Body.fromString("""{"error":"Ride not found"}""")))
          case _                         =>
            ZIO.succeed(
              Response(Status.InternalServerError, body = Body.fromString("""{"error":"Internal server error"}"""))
            )
        }
    }
  )

  // Original routes without dependencies
  val routes = Routes(
    Method.GET / "api" / "v2" / "health"                               -> handler { (_: Request) =>
      ZIO.succeed(Response.text("Ride service is healthy"))
    },
    Method.GET / "api" / "rides" / "mock"                              -> handler { (_: Request) =>
      ZIO.succeed(Response.json(mockRides))
    },
    // Universal flight endpoints - works for any airport
    Method.GET / "api" / "flights" / string("airport") / "arrivals"    -> handler { (airport: String, _: Request) =>
      ZIO.succeed(Response.json(mockArrivals))
    },
    Method.GET / "api" / "flights" / string("airport") / "departures"  -> handler { (airport: String, _: Request) =>
      ZIO.succeed(Response.json(mockDepartures))
    },
    // Airport timing endpoint
    Method.GET / "api" / "airport" / "timing"                          -> handler { (request: Request) =>
      ZIO.succeed(Response.json(mockAirportTiming))
    },
    // Airport timing with flight number
    Method.GET / "api" / "airport" / "timing" / string("flightNumber") -> handler {
      (flightNumber: String, _: Request) =>
        ZIO.succeed(Response.json(mockAirportTiming))
    }
  )

  // Routes with PersonRepository environment for consistency
  val routesWithPersonRepo: Routes[PersonRepository, Response] = Routes(
    Method.GET / "api" / "v2" / "health"                               -> handler { (_: Request) =>
      ZIO.succeed(Response.text("Ride service is healthy"))
    },
    Method.GET / "api" / "rides" / "mock"                              -> handler { (_: Request) =>
      ZIO.succeed(Response.json(mockRides))
    },
    // Universal flight endpoints - works for any airport
    Method.GET / "api" / "flights" / string("airport") / "arrivals"    -> handler { (airport: String, _: Request) =>
      ZIO.succeed(Response.json(mockArrivals))
    },
    Method.GET / "api" / "flights" / string("airport") / "departures"  -> handler { (airport: String, _: Request) =>
      ZIO.succeed(Response.json(mockDepartures))
    },
    // Airport timing endpoint
    Method.GET / "api" / "airport" / "timing"                          -> handler { (request: Request) =>
      ZIO.succeed(Response.json(mockAirportTiming))
    },
    // Airport timing with flight number
    Method.GET / "api" / "airport" / "timing" / string("flightNumber") -> handler {
      (flightNumber: String, _: Request) =>
        ZIO.succeed(Response.json(mockAirportTiming))
    }
  )
}
