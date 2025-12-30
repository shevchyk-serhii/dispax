package com.shevchyk

import java.time.{LocalDateTime, ZoneOffset}
import java.time.format.DateTimeFormatter
import scala.util.Random

object TestDataGenerator {

  case class TestUser(
      id: Int,
      name: String,
      email: String,
      role: String,
      phone: String
  )

  case class TestLocation(
      address: String,
      latitude: Double,
      longitude: Double
  )

  case class TestRide(
      id: Int,
      clientId: Int,
      creatorId: Int,
      driverId: Option[Int],
      companyId: Int,
      pickupDateTime: String,
      from: TestLocation,
      to: TestLocation,
      status: String,
      clientName: String,
      price: Option[Double],
      driverName: Option[String],
      isAirportTransfer: Boolean,
      flightNumber: Option[String] = None,
      isArrival: Option[Boolean] = None,
      gate: Option[String] = None,
      terminal: Option[String] = None,
      flightStatus: Option[String] = None
  )

  private val testUsers = Seq(
    TestUser(1, "Anna Mueller", "anna.mueller@example.com", "client", "+49301234567"),
    TestUser(2, "Peter Schmidt", "peter.schmidt@example.com", "client", "+49301234568"),
    TestUser(3, "Maria Wagner", "maria.wagner@example.com", "client", "+49301234569"),
    TestUser(4, "Klaus Weber", "klaus.weber@example.com", "client", "+49301234570"),
    TestUser(5, "Katharina Fischer", "katharina.fischer@example.com", "client", "+49301234571"),
    TestUser(6, "Thomas Becker", "thomas.becker@example.com", "client", "+49301234572"),
    TestUser(7, "Sabine Schulz", "sabine.schulz@example.com", "client", "+49301234573"),
    TestUser(8, "Andreas Hoffmann", "andreas.hoffmann@example.com", "client", "+49301234574"),
    TestUser(10, "Hans Driver", "hans.driver@oktopus.de", "driver", "+49171234567"),
    TestUser(11, "Fritz Taxi", "fritz.taxi@oktopus.de", "driver", "+49171234568"),
    TestUser(12, "Otto Fahrer", "otto.fahrer@oktopus.de", "driver", "+49171234569"),
    TestUser(13, "Wilhelm Chauffeur", "wilhelm.chauffeur@oktopus.de", "driver", "+49171234570"),
    TestUser(14, "Gunther Pilot", "gunther.pilot@oktopus.de", "driver", "+49171234571"),
    TestUser(15, "Heinrich Mobile", "heinrich.mobile@oktopus.de", "driver", "+49171234572"),
    TestUser(20, "Ingrid Dispatcher", "ingrid.dispatcher@oktopus.de", "dispatcher", "+49301234567"),
    TestUser(21, "Wolfgang Coordinator", "wolfgang.coordinator@oktopus.de", "dispatcher", "+49301234568"),
    TestUser(30, "Greta Secretary", "greta.secretary@oktopus.de", "secretary", "+49301234580"),
    TestUser(31, "Helga Assistant", "helga.assistant@oktopus.de", "secretary", "+49301234581")
  )

  private val germanLocations = Seq(
    TestLocation("Marienplatz", 48.1374, 11.5755),
    TestLocation("Munich Airport", 48.3538, 11.7861),
    TestLocation("Munich Central Station", 48.1405, 11.5563),
    TestLocation("Maximilianstrasse 15", 48.1394, 11.5805),
    TestLocation("BMW Welt", 48.1775, 11.5560),
    TestLocation("Oktoberfest Grounds", 48.1314, 11.5497),
    TestLocation("English Garden", 48.1640, 11.6040),
    TestLocation("Schwabing District", 48.1674, 11.5736),
    TestLocation("Sendlinger Tor", 48.1344, 11.5663),
    TestLocation("Isartor", 48.1349, 11.5802),
    TestLocation("Brandenburg Gate", 52.5163, 13.3777),
    TestLocation("Berlin Airport", 52.3667, 13.5033),
    TestLocation("Berlin Central Station", 52.5255, 13.3690),
    TestLocation("Potsdamer Platz", 52.5096, 13.3759),
    TestLocation("Alexanderplatz", 52.5219, 13.4132),
    TestLocation("Ku'damm 200", 52.5037, 13.3300),
    TestLocation("Checkpoint Charlie", 52.5075, 13.3903),
    TestLocation("Hamburg Airport", 53.6304, 9.9882),
    TestLocation("Hamburg Central Station", 53.5527, 10.0068),
    TestLocation("HafenCity", 53.5411, 10.0025),
    TestLocation("Speicherstadt", 53.5438, 10.0016),
    TestLocation("Reeperbahn 154", 53.5496, 9.9625),
    TestLocation("Alster Lake", 53.5630, 10.0093),
    TestLocation("Frankfurt Airport", 50.0379, 8.5622),
    TestLocation("Frankfurt Central Station", 50.1073, 8.6647),
    TestLocation("Zeil Shopping Street", 50.1154, 8.6818)
  )

  private val rideStatuses   = Seq("requested", "assigned", "inProgress", "completed", "cancelled")
  private val flightNumbers  = Seq("PS123", "LH456", "KL789", "AF321", "BA654", "QR987", "EK147", "TK258")
  private val gates          = Seq("A1", "A2", "A3", "B1", "B2", "B3", "C1", "C2", "D1", "D2")
  private val terminals      = Seq("Terminal 1", "Terminal 2", "Terminal F")
  private val flightStatuses = Seq("On Time", "Delayed", "Boarding", "Departed", "Arrived", "Cancelled")

  def generateUsers(): String = {
    val usersJson = testUsers
      .map { user =>
        s"""{
        "id": ${user.id},
        "name": "${user.name}",
        "email": "${user.email}",
        "role": "${user.role}",
        "phone": "${user.phone}"
      }"""
      }
      .mkString("[\n  ", ",\n  ", "\n]")
    usersJson
  }

  def generateRides(count: Int = 50): String = {
    val random      = new Random()
    val currentTime = LocalDateTime.now()

    val rides = (1 to count).map { i =>
      val client     = testUsers.filter(_.role == "client")(random.nextInt(8))
      val isAssigned = random.nextBoolean()
      val driver     =
        if (isAssigned)
          Some(testUsers.filter(_.role == "driver")(random.nextInt(6)))
        else
          None

      val dayOffset    = random.nextInt(15) - 7
      val hourOffset   = random.nextInt(24)
      val minuteOffset = random.nextInt(60)
      val pickupTime   = currentTime.plusDays(dayOffset).withHour(hourOffset).withMinute(minuteOffset).withSecond(0)

      val from = germanLocations(random.nextInt(germanLocations.length))
      val to   = germanLocations(random.nextInt(germanLocations.length))

      val status =
        if (pickupTime.isBefore(currentTime.minusHours(2))) {
          if (random.nextDouble() < 0.8)
            "completed"
          else
            "cancelled"
        }
        else if (pickupTime.isBefore(currentTime.plusHours(1))) {
          if (driver.isDefined)
            "inProgress"
          else
            "requested"
        }
        else {
          if (driver.isDefined)
            "assigned"
          else
            "requested"
        }

      val price             =
        if (status == "completed")
          Some(20.0 + random.nextDouble() * 80.0)
        else
          None
      val isAirportTransfer = to.address.contains("Airport") || from.address.contains("Airport")

      val (flightNumber, isArrival, gate, terminal, flightStatus) =
        if (isAirportTransfer) {
          (
            Some(flightNumbers(random.nextInt(flightNumbers.length))),
            Some(from.address.contains("Airport")), // true if picking up from airport
            Some(gates(random.nextInt(gates.length))),
            Some(terminals(random.nextInt(terminals.length))),
            Some(flightStatuses(random.nextInt(flightStatuses.length)))
          )
        }
        else {
          (None, None, None, None, None)
        }

      TestRide(
        id = i,
        clientId = client.id,
        creatorId = client.id,
        driverId = driver.map(_.id),
        companyId = 1,
        pickupDateTime = pickupTime.atZone(ZoneOffset.UTC).format(DateTimeFormatter.ISO_INSTANT),
        from = from,
        to = to,
        status = status,
        clientName = client.name,
        price = price,
        driverName = driver.map(_.name),
        isAirportTransfer = isAirportTransfer,
        flightNumber = flightNumber,
        isArrival = isArrival,
        gate = gate,
        terminal = terminal,
        flightStatus = flightStatus
      )
    }

    val ridesJson = rides
      .map { ride =>
        val driverIdJson   = ride.driverId.map(_.toString).getOrElse("null")
        val priceJson      = ride.price.map(_.formatted("%.2f")).getOrElse("null")
        val driverNameJson = ride.driverName.map(name => s""""$name"""").getOrElse("null")

        val flightFields =
          if (ride.isAirportTransfer) {
            val flightNumberJson = ride.flightNumber.map(f => s""""$f"""").getOrElse("null")
            val isArrivalJson    = ride.isArrival.map(_.toString).getOrElse("null")
            val gateJson         = ride.gate.map(g => s""""$g"""").getOrElse("null")
            val terminalJson     = ride.terminal.map(t => s""""$t"""").getOrElse("null")
            val flightStatusJson = ride.flightStatus.map(s => s""""$s"""").getOrElse("null")

            s""",
        "flightNumber": $flightNumberJson,
        "isArrival": $isArrivalJson,
        "gate": $gateJson,
        "terminal": $terminalJson,
        "flightStatus": $flightStatusJson"""
          }
          else
            ""

        s"""{
        "id": ${ride.id},
        "clientId": ${ride.clientId},
        "creatorId": ${ride.creatorId},
        "driverId": $driverIdJson,
        "companyId": ${ride.companyId},
        "pickupDateTime": "${ride.pickupDateTime}",
        "from": {
          "address": "${ride.from.address}",
          "latitude": ${ride.from.latitude},
          "longitude": ${ride.from.longitude}
        },
        "to": {
          "address": "${ride.to.address}",
          "latitude": ${ride.to.latitude},
          "longitude": ${ride.to.longitude}
        },
        "status": "${ride.status}",
        "clientName": "${ride.clientName}",
        "price": $priceJson,
        "driverName": $driverNameJson,
        "isAirportTransfer": ${ride.isAirportTransfer}$flightFields
      }"""
      }
      .mkString("[\n  ", ",\n  ", "\n]")

    ridesJson
  }

  def generateStats(): Map[String, Int] = {
    val rides      = (1 to 50).map(_ => rideStatuses(Random.nextInt(rideStatuses.length)))
    Map(
      "total"      -> rides.length,
      "completed"  -> rides.count(_ == "completed"),
      "inProgress" -> rides.count(_ == "inProgress"),
      "requested"  -> rides.count(_ == "requested"),
      "assigned"   -> rides.count(_ == "assigned"),
      "cancelled"  -> rides.count(_ == "cancelled")
    )
  }
}
