package com.shevchyk.service

import com.shevchyk.domain.{Ride, Location, RideStatus, PersonRole, PersonPublic}
import zio.*
import java.time.LocalDateTime

trait RideService {
  def getAllRides: Task[List[Ride]]
  def getRidesForUser(user: PersonPublic): Task[List[Ride]]
  def getRideById(id: Long): Task[Option[Ride]]
  def createRide(ride: Ride): Task[Ride]
  def updateRide(id: Long, ride: Ride): Task[Option[Ride]]
  def deleteRide(id: Long): Task[Boolean]
  def enrichWithFlightInfo(ride: Ride): Task[Ride]
}

case class RideServiceImpl() extends RideService {

  override def getAllRides: Task[List[Ride]] = ZIO.succeed(RideService.mockRides.values.toList)

  override def getRidesForUser(user: PersonPublic): Task[List[Ride]] = ZIO.succeed {
    val allRides = RideService.mockRides.values.toList

    user.role match {
      case PersonRole.driver =>
        // Driver sees only rides assigned to them
        allRides.filter(_.driverId.contains(user.id))

      case PersonRole.client =>
        // Client sees only their own rides
        allRides.filter(_.clientId == user.id)

      case PersonRole.secretary | PersonRole.dispatcher =>
        // Secretary and Dispatcher see all rides in their company
        user.companyId match {
          case Some(companyId) => allRides.filter(_.companyId == companyId)
          case None            => List.empty
        }
    }
  }

  override def getRideById(id: Long): Task[Option[Ride]] = ZIO.succeed(RideService.mockRides.get(id))

  override def createRide(ride: Ride): Task[Ride] =
    for {
      newId  <- Random.nextLong.map(math.abs)
      newRide = ride.copy(id = newId)
    } yield newRide

  override def updateRide(id: Long, ride: Ride): Task[Option[Ride]] = ZIO.succeed {
    if (RideService.mockRides.contains(id)) {
      Some(ride.copy(id = id))
    }
    else {
      None
    }
  }

  override def deleteRide(id: Long): Task[Boolean] = ZIO.succeed(RideService.mockRides.contains(id))
  
  override def enrichWithFlightInfo(ride: Ride): Task[Ride] = 
    if (ride.isAirportTransfer && ride.flightNumber.isDefined) {
      (for {
        flightService <- ZIO.service[FlightService]
        currentTime   = java.lang.System.currentTimeMillis() / 1000
        // Search for flights in ±6 hours window
        beginTime     = currentTime - 6 * 3600
        endTime       = currentTime + 6 * 3600
        arrivals     <- flightService.getMunichArrivals(beginTime, endTime)
        departures   <- flightService.getMunichDepartures(beginTime, endTime)
        allFlights    = arrivals ++ departures
        flightInfo   <- ZIO.succeed {
          allFlights.find(_.callsign.trim == ride.flightNumber.getOrElse("").trim)
        }
        enrichedRide <- ZIO.succeed {
          flightInfo match {
            case Some(flight) =>
              // Determine if it's arrival or departure based on location
              val isFromAirport = ride.from.address.toLowerCase.contains("airport")
              val isArrival = !isFromAirport // если начинаем не в аэропорту - значит прилет
              val flightTime = if (isFromAirport) {
                // Departure flight
                java.time.LocalDateTime.ofEpochSecond(flight.firstSeen, 0, java.time.ZoneOffset.UTC)
              } else {
                // Arrival flight  
                java.time.LocalDateTime.ofEpochSecond(flight.lastSeen, 0, java.time.ZoneOffset.UTC)
              }
              // Mock data for gate and terminal
              val gate = Some(s"${('A' + scala.util.Random.nextInt(6)).toChar}${scala.util.Random.nextInt(20) + 1}")
              val terminal = Some(if (scala.util.Random.nextBoolean()) "1" else "2")
              val status = if (scala.util.Random.nextDouble() > 0.8) Some("Delayed") else Some("On Time")
              
              ride.copy(
                flightTime = Some(flightTime),
                isArrival = isArrival,
                gate = gate,
                terminal = terminal,
                flightStatus = status
              )
            case None =>
              ride
          }
        }
      } yield enrichedRide).provideSomeLayer(FlightService.live)
    } else {
      ZIO.succeed(ride)
    }
}

object RideService {
  val layer: ULayer[RideService] = ZLayer.succeed(RideServiceImpl())

  // Mock data for testing
  val mockRides: Map[Long, Ride] = Map(
    // Rides for Anna Client (ID=2)
    1L -> Ride(
      id = 1L,
      clientId = 2,       // Anna Client
      creatorId = 3,      // Maria Secretary created this ride
      driverId = Some(1), // Assigned to John Driver
      companyId = 1,
      pickupDateTime = LocalDateTime.now().plusHours(2),
      from = Location(address = "Downtown Munich"),
      to = Location(address = "Munich Airport (MUC)"),
      status = RideStatus.Assigned,
      flightNumber = Some("LH123"),
      isAirportTransfer = true,
      isArrival = false, // отлет
      gate = Some("A12"),
      terminal = Some("2"),
      flightStatus = Some("On Time")
    ),
    2L -> Ride(
      id = 2L,
      clientId = 2,  // Anna Client
      creatorId = 3, // Maria Secretary
      companyId = 1,
      pickupDateTime = LocalDateTime.now().plusHours(5),
      from = Location(address = "Railway Station"),
      to = Location(address = "Kiev National University"),
      status = RideStatus.Requested
    ),
    3L -> Ride(
      id = 3L,
      clientId = 2,       // Anna Client
      creatorId = 4,      // Peter Dispatcher
      driverId = Some(1), // Assigned to John Driver
      companyId = 1,
      pickupDateTime = LocalDateTime.now().plusDays(1),
      from = Location(address = "Independence Square"),
      to = Location(address = "Golden Gate"),
      status = RideStatus.InProgress
    ),
    4L -> Ride(
      id = 4L,
      clientId = 2,  // Anna Client
      creatorId = 3, // Maria Secretary
      companyId = 1,
      pickupDateTime = LocalDateTime.now().minusHours(2),
      from = Location(address = "Hotel Ukraine"),
      to = Location(address = "St. Sophia Cathedral"),
      status = RideStatus.Completed
    ),

    // Additional rides for other scenarios
    5L -> Ride(
      id = 5L,
      clientId = 5,       // Another client
      creatorId = 3,      // Maria Secretary
      driverId = Some(1), // Assigned to John Driver
      companyId = 1,
      pickupDateTime = LocalDateTime.now().plusHours(3),
      from = Location(address = "Munich Airport (MUC)"),
      to = Location(address = "Munich Central Station"),
      status = RideStatus.Assigned,
      flightNumber = Some("BA456"),
      isAirportTransfer = true,
      isArrival = true, // прилет
      gate = Some("B7"),
      terminal = Some("1"),
      flightStatus = Some("Delayed")
    ),
    6L -> Ride(
      id = 6L,
      clientId = 6,       // Another client
      creatorId = 4,      // Peter Dispatcher
      driverId = Some(1), // Assigned to John Driver
      companyId = 1,
      pickupDateTime = LocalDateTime.now().plusHours(4),
      from = Location(address = "Khreshchatyk Street"),
      to = Location(address = "Olympic Stadium"),
      status = RideStatus.InProgress
    ),
    7L -> Ride(
      id = 7L,
      clientId = 7,  // Another client
      creatorId = 3, // Maria Secretary
      companyId = 1,
      pickupDateTime = LocalDateTime.now().plusHours(6),
      from = Location(address = "Arsenalna Metro"),
      to = Location(address = "St. Andrew's Church"),
      status = RideStatus.Requested
    ),
    8L -> Ride(
      id = 8L,
      clientId = 8,       // Another client
      creatorId = 4,      // Peter Dispatcher
      driverId = Some(1), // Assigned to John Driver
      companyId = 1,
      pickupDateTime = LocalDateTime.now().minusHours(1),
      from = Location(address = "Bessarabsky Market"),
      to = Location(address = "Friendship of Nations Arch"),
      status = RideStatus.Completed
    )
  )
}
