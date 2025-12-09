package com.shevchyk.app.routes

import com.shevchyk.infrastructure.testdata.*
import zio.*
import zio.http.*
import zio.json.*

object AdminRoutes:

  def routes: Routes[TestDataSeeder, Response] = Routes(
    // Generate test data
    Method.POST / "admin" / "test-data" / "seed" -> handler { (req: Request) =>
      for
        body   <- req.body.asString
        config <-
          body match
            case "small" => ZIO.succeed(TestDataConfig.small)
            case "large" => ZIO.succeed(TestDataConfig.large)
            case ""      => ZIO.succeed(TestDataConfig.default)
            case json    =>
              ZIO
                .fromEither(json.fromJson[TestDataConfig])
                .mapError(e => new RuntimeException(s"Invalid config JSON: $e"))
        seeder <- ZIO.service[TestDataSeeder]
        result <- seeder.seedTestData(config)
      yield Response.json(s"""{"success":true,"message":"Test data generated successfully"}""")
    }.catchAll { error =>
      handler(
        ZIO.succeed(
          Response.json(s"""{"success":false,"error":"${error.getMessage}"}""").status(Status.InternalServerError)
        )
      )
    },

    // Clear test data
    Method.DELETE / "admin" / "test-data" -> handler { (_: Request) =>
      for
        seeder <- ZIO.service[TestDataSeeder]
        _      <- seeder.clearAllData()
      yield Response.json(s"""{"success":true,"message":"Test data cleared"}""")
    }.catchAll { error =>
      handler(
        ZIO.succeed(
          Response.json(s"""{"success":false,"error":"${error.getMessage}"}""").status(Status.InternalServerError)
        )
      )
    },

    // Get test data info
    Method.GET / "admin" / "test-data" / "info" -> handler { (_: Request) =>
      ZIO.succeed(
        Response.json(s"""{"info":"Use POST /admin/test-data/seed with body 'small', 'large' or empty for default"}""")
      )
    }
  )
