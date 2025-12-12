package com.shevchyk.app.routes

import com.shevchyk.TestDataGenerator
import zio.*
import zio.http.*
import zio.json.*

object UserRoutes {

  // Generate rich test users data
  private lazy val mockUsers = TestDataGenerator.generateUsers()

  val routes = Routes(
    Method.GET / "api" / "users"             -> handler { (_: Request) =>
      ZIO.succeed(Response.json(mockUsers))
    },
    Method.GET / "api" / "users" / int("id") -> handler { (userId: Int, _: Request) =>
      val usersJson = TestDataGenerator.generateUsers()
      ZIO.succeed(
        Response.json(s"""{"id": $userId, "name": "Test User", "email": "test$userId@example.com", "role": "client"}""")
      )
    },
    Method.GET / "api" / "users" / "drivers" -> handler { (_: Request) =>
      // Filter drivers from generated users
      val driversJson = """[
        {"id": 10, "name": "Hans Driver", "email": "hans.driver@oktopus.de", "role": "driver", "phone": "+49171234567", "rating": 4.8, "totalRides": 156},
        {"id": 11, "name": "Fritz Taxi", "email": "fritz.taxi@oktopus.de", "role": "driver", "phone": "+49171234568", "rating": 4.7, "totalRides": 203},
        {"id": 12, "name": "Otto Fahrer", "email": "otto.fahrer@oktopus.de", "role": "driver", "phone": "+49171234569", "rating": 4.9, "totalRides": 89},
        {"id": 13, "name": "Wilhelm Chauffeur", "email": "wilhelm.chauffeur@oktopus.de", "role": "driver", "phone": "+49171234570", "rating": 4.6, "totalRides": 142},
        {"id": 14, "name": "Gunther Pilot", "email": "gunther.pilot@oktopus.de", "role": "driver", "phone": "+49171234571", "rating": 4.8, "totalRides": 98},
        {"id": 15, "name": "Heinrich Mobile", "email": "heinrich.mobile@oktopus.de", "role": "driver", "phone": "+49171234572", "rating": 4.5, "totalRides": 176}
      ]"""
      ZIO.succeed(Response.json(driversJson))
    },
    Method.GET / "api" / "users" / "clients" -> handler { (_: Request) =>
      // Filter clients from generated users
      val clientsJson = """[
        {"id": 1, "name": "Anna Mueller", "email": "anna.mueller@example.com", "role": "client", "phone": "+49301234567", "totalRides": 23},
        {"id": 2, "name": "Peter Schmidt", "email": "peter.schmidt@example.com", "role": "client", "phone": "+49301234568", "totalRides": 15},
        {"id": 3, "name": "Maria Wagner", "email": "maria.wagner@example.com", "role": "client", "phone": "+49301234569", "totalRides": 31},
        {"id": 4, "name": "Klaus Weber", "email": "klaus.weber@example.com", "role": "client", "phone": "+49301234570", "totalRides": 8},
        {"id": 5, "name": "Katharina Fischer", "email": "katharina.fischer@example.com", "role": "client", "phone": "+49301234571", "totalRides": 42},
        {"id": 6, "name": "Thomas Becker", "email": "thomas.becker@example.com", "role": "client", "phone": "+49301234572", "totalRides": 19},
        {"id": 7, "name": "Sabine Schulz", "email": "sabine.schulz@example.com", "role": "client", "phone": "+49301234573", "totalRides": 27},
        {"id": 8, "name": "Andreas Hoffmann", "email": "andreas.hoffmann@example.com", "role": "client", "phone": "+49301234574", "totalRides": 12}
      ]"""
      ZIO.succeed(Response.json(clientsJson))
    },
    Method.GET / "api" / "stats" / "rides"   -> handler { (_: Request) =>
      val stats     = TestDataGenerator.generateStats()
      val statsJson =
        s"""{
        "totalRides": ${stats("total")},
        "completedRides": ${stats("completed")},
        "inProgressRides": ${stats("inProgress")},
        "requestedRides": ${stats("requested")},
        "assignedRides": ${stats("assigned")},
        "cancelledRides": ${stats("cancelled")},
        "activeDrivers": 6,
        "totalClients": 8,
        "todayRevenue": ${scala.util.Random.nextInt(5000) + 2000}.00,
        "monthlyRevenue": ${scala.util.Random.nextInt(50000) + 25000}.00
      }"""
      ZIO.succeed(Response.json(statsJson))
    }
  )
}
