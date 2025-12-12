package com.shevchyk.app.routes

import com.shevchyk.repository.PersonRepository
import com.shevchyk.core.domain.{Person, PersonId, PersonRole}
import zio.*
import zio.http.*
import zio.json.*

object UserRoutes {

  val routes: Routes[PersonRepository, Throwable] = Routes(
    Method.GET / "api" / "users"             -> handler { (_: Request) =>
      for {
        personRepo <- ZIO.service[PersonRepository]
        users      <- personRepo.findAll()
        response   <- ZIO.succeed(Response.json(users.toJson))
      } yield response
    },
    Method.GET / "api" / "users" / int("id") -> handler { (userId: Int, _: Request) =>
      for {
        personRepo <- ZIO.service[PersonRepository]
        userOpt    <- personRepo.findById(PersonId(userId))
        response   <-
          userOpt match {
            case Some(user) => ZIO.succeed(Response.json(user.toJson))
            case None       => ZIO.succeed(Response.status(Status.NotFound))
          }
      } yield response
    },
    Method.GET / "api" / "users" / "drivers" -> handler { (_: Request) =>
      for {
        personRepo <- ZIO.service[PersonRepository]
        drivers    <- personRepo.findByRole(PersonRole.Driver)
        response   <- ZIO.succeed(Response.json(drivers.toJson))
      } yield response
    },
    Method.GET / "api" / "users" / "clients" -> handler { (_: Request) =>
      for {
        personRepo <- ZIO.service[PersonRepository]
        clients    <- personRepo.findByRole(PersonRole.Client)
        response   <- ZIO.succeed(Response.json(clients.toJson))
      } yield response
    },
    Method.GET / "api" / "stats" / "rides"   -> handler { (_: Request) =>
      for {
        personRepo <- ZIO.service[PersonRepository]
        drivers    <- personRepo.findByRole(PersonRole.Driver)
        clients    <- personRepo.findByRole(PersonRole.Client)
        statsJson   =
          s"""{
          "totalRides": ${scala.util.Random.nextInt(100) + 50},
          "completedRides": ${scala.util.Random.nextInt(40) + 20},
          "inProgressRides": ${scala.util.Random.nextInt(10) + 2},
          "requestedRides": ${scala.util.Random.nextInt(15) + 5},
          "assignedRides": ${scala.util.Random.nextInt(12) + 3},
          "cancelledRides": ${scala.util.Random.nextInt(8) + 1},
          "activeDrivers": ${drivers.length},
          "totalClients": ${clients.length},
          "todayRevenue": ${scala.util.Random.nextInt(5000) + 2000}.00,
          "monthlyRevenue": ${scala.util.Random.nextInt(50000) + 25000}.00
        }"""
        response   <- ZIO.succeed(Response.json(statsJson))
      } yield response
    }
  )
}
