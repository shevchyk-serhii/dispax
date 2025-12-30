package com.shevchyk.ride.infrastructure.http

import com.shevchyk.TestDataGenerator
import com.shevchyk.core.domain.{PersonId, RideId, CompanyId}
import com.shevchyk.ride.application.RideFacade
import com.shevchyk.ride.domain.{*, given}
import com.shevchyk.auth.middleware.{AuthMiddleware, AuthenticatedUser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.auth.infrastructure.http.AuthenticatedHandlers.*
import zio.*
import zio.http.*
import zio.json.*

import java.util.UUID

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

  val authenticatedRoutes: Routes[RideFacade & JwtService, Response] = Routes(
    // Create new ride (authenticated)
    Method.POST / "api" / "rides" -> authenticatedJsonHandler[RideFacade, CreateRideApiRequest] { (user, apiRequest) =>
      (for {
        // Use companyId from JWT token (authenticated user)
        companyId    <- ZIO
                          .fromOption(user.companyId)
                          .orElseFail(
                            new RuntimeException("User must belong to a company to create rides")
                          )
        domainRequest = CreateRideApiRequest
                          .toDomain(apiRequest, CompanyId(companyId))
                          .copy(clientId = PersonId(user.userId))
        facade       <- ZIO.service[RideFacade]
        ride         <- facade.createRide(domainRequest)
        rideDto       = RideDto.fromDomain(ride)
      } yield Response(Status.Created, body = Body.fromString(rideDto.toJson)))
        .catchAll { ex =>
          ZIO.logError(s"Create ride error: ${ex.getMessage}") *>
            ZIO.succeed(Response(Status.BadRequest, body = Body.fromString(s"""{"error":"${ex.getMessage}"}""")))
        }
    },

    // Get all rides for authenticated user
    Method.GET / "api" / "rides" -> authenticatedHandler[RideFacade] { (user, _) =>
      for {
        facade  <- ZIO.service[RideFacade]
        rides   <- facade.getRidesForUser(PersonId(user.userId))
        rideDtos = rides.map(RideDto.fromDomain)
      } yield Response.json(rideDtos.toJson)
    },

    // Get specific ride by ID (authenticated)
    Method.GET / "api" / "rides" / string("rideId") -> handler { (rideId: String, request: Request) =>
      (for {
        user   <- AuthMiddleware.authenticateRequest(request)
        facade <- ZIO.service[RideFacade]
        ride   <- facade.getRideById(RideId(UUID.fromString(rideId)))
        // TODO: Add authorization check - ensure user owns this ride or has permission
        rideDto = RideDto.fromDomain(ride)
      } yield Response.json(rideDto.toJson)).catchAll {
        case response: Response => ZIO.succeed(response) // Auth errors
        case ex: Throwable      =>
          ZIO.succeed(Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"${ex.getMessage}"}""")))
      }
    },

    // Calculate optimal airport entry time (authenticated)
    Method.POST / "api" / "rides" / string("rideId") / "airport-timing" -> handler {
      (rideId: String, request: Request) =>
        (for {
          user   <- AuthMiddleware.authenticateRequest(request)
          facade <- ZIO.service[RideFacade]
          ride   <- facade.getRideById(RideId(UUID.fromString(rideId)))

          // Mock calculation - in production, this would use real-time data
          now        = java.time.Instant.now()
          flightTime = ride.scheduledTime.getOrElse(now.plusSeconds(7200))

          // Calculate times
          travelTime = 45 // minutes
          bufferTime = 30 // minutes (security + check-in)
          totalTime  = travelTime + bufferTime

          optimalEntry = flightTime.minusSeconds(totalTime * 60)
          latestEntry  = flightTime.minusSeconds(bufferTime * 60)
          timeToDepart = java.time.Duration.between(now, optimalEntry).toMinutes.toInt

          // Mock parking costs
          optimalCost = 12.50
          earlyCost   = 25.00
          savings     = earlyCost - optimalCost

          response =
            s"""{
          "optimalEntryTime": "${optimalEntry}",
          "latestEntryTime": "${latestEntry}",
          "travelTimeMinutes": $travelTime,
          "bufferTimeMinutes": $bufferTime,
          "optimalParkingCost": $optimalCost,
          "earlyEntryParkingCost": $earlyCost,
          "savings": $savings,
          "flightStatus": "On time",
          "timeToDepartMinutes": $timeToDepart
        }"""

        } yield Response.json(response)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      =>
            ZIO.succeed(Response(Status.NotFound, body = Body.fromString(s"""{"error":"${ex.getMessage}"}""")))
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
    Method.GET / "api" / "airport" / "timing" / string("flightNumber") -> handler {
      (flightNumber: String, _: Request) =>
        ZIO.succeed(Response.json(mockAirportTiming))
    }
  )
}
