package com.shevchyk.infrastructure.testdata

import zio.*

object TestDataInitializer:

  enum Environment:
    case Dev, Int, Prod

  def getEnvironment: Environment =
    sys.env.get("ENV") match
      case Some("dev") | Some("development") => Environment.Dev
      case Some("int") | Some("integration") => Environment.Int
      case Some("prod") | Some("production") => Environment.Prod
      case _                                 => Environment.Dev // default to dev

  val autoSeedLayer: ZLayer[TestDataSeeder, Nothing, Unit] = ZLayer.fromZIO {
    val env = getEnvironment

    env match
      case Environment.Dev  =>
        (for
          _      <- Console.printLine(s"🧪 ${env} environment detected - auto-seeding development test data...")
          seeder <- ZIO.service[TestDataSeeder]
          result <- seeder.seedTestData(TestDataConfig.default)
          _      <- Console.printLine("✅ Development test data auto-seeded successfully!")
        yield ()).catchAll { error =>
          ZIO.logError(s"❌ Failed to seed test data: ${error.getMessage}") *>
            ZIO.unit
        }
      case Environment.Int  =>
        (for
          _      <- Console.printLine(s"🧪 ${env} environment detected - auto-seeding integration test data...")
          seeder <- ZIO.service[TestDataSeeder]
          result <- seeder.seedTestData(TestDataConfig.small)
          _      <- Console.printLine("✅ Integration test data auto-seeded successfully!")
        yield ()).catchAll { error =>
          ZIO.logError(s"❌ Failed to seed test data: ${error.getMessage}") *>
            ZIO.unit
        }
      case Environment.Prod => ZIO.logInfo("🏭 Production environment - test data not auto-seeded.")
  }
