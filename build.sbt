ThisBuild / version      := "0.1.0-SNAPSHOT"
ThisBuild / scalaVersion := "3.3.7"

// Test-coverage (scoverage) exclusions: generated/derived/wiring code that carries
// no testable logic — domain case classes & DTOs (data only), the DI/bootstrap
// entrypoints, and the test-only in-memory app. Coverage stays focused on
// application logic, HTTP endpoints and repositories.
ThisBuild / coverageExcludedPackages := Seq(
  "com\\.shevchyk\\.Application",
  "com\\.shevchyk\\.TestApplication",
  ".*\\.domain\\..*",
  ".*\\.infrastructure\\.http\\.dto\\..*"
).mkString(";")

// Strict compiler flags. In a ZIO codebase the most valuable are -Wvalue-discard
// and -Wnonunit-statement: they catch effects that are constructed but never
// chained into the program (a silently-dropped ZIO that never runs). We keep
// warnings non-fatal for now so the build still succeeds while the existing
// findings are cleaned up incrementally.
ThisBuild / scalacOptions ++= Seq(
  "-deprecation",
  "-feature",
  "-unchecked",
  "-Wunused:all",
  "-Wvalue-discard",
  "-Wnonunit-statement"
)

// Integration specs share a single reusable Postgres container
// (see PostgresTestContainer) and isolate themselves by TRUNCATE-ing + re-seeding
// their tables on each test. That isolation only holds if specs run one at a time
// against the shared DB — otherwise one spec's TRUNCATE wipes another's data
// mid-run. Disabling parallel test execution serialises specs within each module
// so the shared DB stays consistent. The big speed win comes from container reuse,
// not from cross-spec parallelism (which would be unsafe on a shared DB).
ThisBuild / Test / parallelExecution := false

ThisBuild / assembly / assemblyMergeStrategy := {
  case x if x.endsWith("module-info.class")            => MergeStrategy.discard
  case x if x.contains("io.netty.versions.properties") => MergeStrategy.first
  case x if x.contains("deriving.conf")                => MergeStrategy.first
  case PathList("META-INF", "services", xs @ _*)       => MergeStrategy.filterDistinctLines
  case PathList("META-INF", "versions", _*)            => MergeStrategy.first
  case PathList("META-INF", xs @ _*)                   => MergeStrategy.discard
  case x                                               => MergeStrategy.first
}

addCommandAlias("fmt", "; scalafmt ; scalafmtSbt")
addCommandAlias("fmtDart", "! dart format /Users/shevchyk/projects/private/dispax/app/lib/ --set-exit-if-changed")
addCommandAlias("fmtAll", "; fmt ; fmtDart")
addCommandAlias("fmtWatch", "~fmtAll")
addCommandAlias("cucumber", "testOnly *CucumberRunner")
addCommandAlias("cucumberWithServer", "; testServer & ; cucumber ; Test / runMain com.shevchyk.TestApplication")
addCommandAlias("testServer", "Test / runMain com.shevchyk.TestApplication")
// `app.env` mirrors the APP_ENV env var (Environment.current reads both). The app derives the
// HOCON profile (application-<env>.conf) from it, so these aliases only set the single selector.
addCommandAlias(
  "runDev",
  "; set Compile / run / javaOptions += \"-Dapp.env=development\"; run"
)
addCommandAlias(
  "runProd",
  "; set Compile / run / javaOptions += \"-Dapp.env=production\"; run"
)

lazy val commonDependencies = Seq(
  "dev.zio"       %% "zio"                % "2.1.9",
  "dev.zio"       %% "zio-logging-slf4j2" % "2.3.1",
  "ch.qos.logback" % "logback-classic"    % "1.5.15",
  "dev.zio"       %% "zio-test"           % "2.1.9" % Test,
  "dev.zio"       %% "zio-test-sbt"       % "2.1.9" % Test,
  "dev.zio"       %% "zio-test-magnolia"  % "2.1.9" % Test
)

lazy val httpDependencies = Seq(
  "dev.zio" %% "zio-http" % "3.0.1"
)

lazy val jsonDependencies = Seq(
  "dev.zio" %% "zio-json" % "0.7.3"
)

// Tapir: declarative endpoint descriptions used to generate OpenAPI + Swagger UI
// and to interpret the same endpoints on the zio-http server. Version 1.11.x is
// compatible with Scala 3.3.x, ZIO 2.1.x and zio-http 3.0.x.
lazy val tapirVersion = "1.11.10"

lazy val tapirDependencies = Seq(
  "com.softwaremill.sttp.tapir" %% "tapir-core"     % tapirVersion,
  "com.softwaremill.sttp.tapir" %% "tapir-zio"      % tapirVersion,
  "com.softwaremill.sttp.tapir" %% "tapir-json-zio" % tapirVersion
)

// Server interpreter + bundled Swagger UI. Only the api (root) module that mounts
// the HTTP server needs these.
lazy val tapirServerDependencies = Seq(
  "com.softwaremill.sttp.tapir" %% "tapir-zio-http-server"   % tapirVersion,
  "com.softwaremill.sttp.tapir" %% "tapir-swagger-ui-bundle" % tapirVersion
)

lazy val circeDependencies = Seq(
  "io.circe" %% "circe-core"    % "0.14.10",
  "io.circe" %% "circe-generic" % "0.14.10",
  "io.circe" %% "circe-parser"  % "0.14.10"
)

lazy val monocleDependencies = Seq(
  "dev.optics" %% "monocle-core"  % "3.3.0",
  "dev.optics" %% "monocle-macro" % "3.3.0"
)

// iron: zero-cost compile-time refinement types. Domain invariants ("non-empty",
// "in range") become part of the type rather than runtime checks scattered across
// services. The zio-json module gives codecs for refined types out of the box.
lazy val ironVersion = "2.6.0"

lazy val ironDependencies = Seq(
  "io.github.iltotore" %% "iron"          % ironVersion,
  "io.github.iltotore" %% "iron-zio-json" % ironVersion
)

lazy val dbDependencies = Seq(
  "org.tpolecat"  %% "doobie-core"                % "1.0.0-RC5",
  "org.tpolecat"  %% "doobie-postgres"            % "1.0.0-RC5",
  "org.tpolecat"  %% "doobie-postgres-circe"      % "1.0.0-RC5",
  "org.tpolecat"  %% "doobie-hikari"              % "1.0.0-RC5",
  "org.postgresql" % "postgresql"                 % "42.7.4",
  "org.flywaydb"   % "flyway-core"                % "10.20.1",
  "org.flywaydb"   % "flyway-database-postgresql" % "10.20.1",
  "dev.zio"       %% "zio-interop-cats"           % "23.1.0.3"
)

lazy val configDependencies = Seq(
  "dev.zio" %% "zio-config"          % "4.0.2",
  "dev.zio" %% "zio-config-magnolia" % "4.0.2",
  "dev.zio" %% "zio-config-typesafe" % "4.0.2"
)

lazy val jwtDependencies = Seq(
  "com.github.jwt-scala" %% "jwt-zio-json" % "10.0.1"
)

lazy val bcryptDependencies = Seq(
  "org.mindrot" % "jbcrypt" % "0.4"
)

lazy val uuidDependencies = Seq(
  "com.github.f4b6a3" % "uuid-creator" % "5.3.2"
)

lazy val testcontainersDependencies = Seq(
  "com.dimafeng" %% "testcontainers-scala-postgresql" % "0.41.4" % Test,
  "com.dimafeng" %% "testcontainers-scala-core"       % "0.41.4" % Test
)

lazy val testDependencies = Seq(
  "io.cucumber"        % "cucumber-core"          % "7.15.0" % Test,
  "io.cucumber"       %% "cucumber-scala"         % "8.20.0" % Test,
  "io.cucumber"        % "cucumber-junit"         % "7.15.0" % Test,
  "org.junit.platform" % "junit-platform-console" % "1.10.1" % Test,
  "junit"              % "junit"                  % "4.13.2" % Test,
  "com.novocode"       % "junit-interface"        % "0.11"   % Test
)

lazy val core = (project in file("core"))
  .settings(
    name := "dispax-core",
    libraryDependencies ++= commonDependencies ++ configDependencies ++ jsonDependencies ++ httpDependencies ++ dbDependencies ++ uuidDependencies ++ tapirDependencies ++ ironDependencies ++ testcontainersDependencies,
    Test / unmanagedResourceDirectories += baseDirectory.value / ".." / "api" / "src" / "main" / "resources"
  )

lazy val auth = (project in file("auth"))
  .dependsOn(core % "compile->compile;test->test")
  .settings(
    name := "dispax-auth",
    libraryDependencies ++= commonDependencies ++ httpDependencies ++ dbDependencies ++ jwtDependencies ++ bcryptDependencies ++ tapirDependencies ++ testcontainersDependencies,
    Test / unmanagedResourceDirectories += baseDirectory.value / ".." / "api" / "src" / "main" / "resources"
  )

lazy val ride = (project in file("ride"))
  .dependsOn(
    core % "compile->compile;test->test",
    auth % "compile->compile;test->test"
  )
  .settings(
    name := "dispax-ride",
    libraryDependencies ++= commonDependencies ++ httpDependencies ++ dbDependencies ++ jsonDependencies ++ circeDependencies ++ monocleDependencies ++ tapirDependencies ++ testcontainersDependencies,
    scalacOptions += "-Xmax-inlines:64",
    Test / unmanagedResourceDirectories += baseDirectory.value / ".." / "api" / "src" / "main" / "resources"
  )

lazy val driver = (project in file("driver"))
  .dependsOn(
    core % "compile->compile;test->test",
    auth % "compile->compile;test->test",
    ride % "compile->compile;test->test"
  )
  .settings(
    name := "dispax-driver",
    libraryDependencies ++= commonDependencies ++ httpDependencies ++ dbDependencies ++ jsonDependencies ++ tapirDependencies
  )

lazy val schedule = (project in file("schedule"))
  .dependsOn(
    core % "compile->compile;test->test",
    auth % "compile->compile;test->test"
  )
  .settings(
    name := "dispax-schedule",
    libraryDependencies ++= commonDependencies ++ httpDependencies ++ dbDependencies ++ jsonDependencies ++ tapirDependencies ++ testcontainersDependencies,
    Test / unmanagedResourceDirectories += baseDirectory.value / ".." / "api" / "src" / "main" / "resources"
  )

lazy val firebaseDependencies = Seq(
  "com.google.firebase" % "firebase-admin" % "9.3.0"
)

lazy val notification = (project in file("notification"))
  .dependsOn(core % "compile->compile;test->test")
  .settings(
    name := "dispax-notification",
    libraryDependencies ++= commonDependencies ++ jsonDependencies ++ dbDependencies ++ firebaseDependencies ++ testcontainersDependencies,
    // Integration tests load Flyway migrations from the api resources.
    Test / unmanagedResourceDirectories += baseDirectory.value / ".." / "api" / "src" / "main" / "resources"
  )

lazy val pdfDependencies = Seq(
  "com.github.librepdf" % "openpdf" % "2.0.3"
)

lazy val billing = (project in file("billing"))
  .dependsOn(
    core % "compile->compile;test->test",
    auth % "compile->compile;test->test",
    ride % "compile->compile;test->test"
  )
  .settings(
    name := "dispax-billing",
    libraryDependencies ++= commonDependencies ++ httpDependencies ++ dbDependencies ++ jsonDependencies ++ pdfDependencies ++ tapirDependencies ++ testcontainersDependencies,
    Test / unmanagedResourceDirectories += baseDirectory.value / ".." / "api" / "src" / "main" / "resources"
  )

lazy val root = (project in file("."))
  .aggregate(core, auth, ride, driver, notification, schedule, billing)
  .dependsOn(core, auth, ride, driver, notification, schedule, billing)
  .settings(
    name                        := "dispax",
    Compile / scalaSource       := baseDirectory.value / "api" / "src" / "main" / "scala",
    Compile / resourceDirectory := baseDirectory.value / "api" / "src" / "main" / "resources",
    Test / scalaSource          := baseDirectory.value / "api" / "src" / "test" / "scala",
    Test / resourceDirectory    := baseDirectory.value / "api" / "src" / "test" / "resources",
    libraryDependencies ++= commonDependencies ++ httpDependencies ++ dbDependencies ++ configDependencies ++ bcryptDependencies ++ tapirDependencies ++ tapirServerDependencies ++ testDependencies,
    testFrameworks ++= Seq(
      new TestFramework("zio.test.sbt.ZTestFramework"),
      new TestFramework("com.novocode.junit.JUnitFramework")
    ),
    Compile / mainClass         := Some("com.shevchyk.Application"),
    assembly / mainClass        := Some("com.shevchyk.Application"),
    assembly / assemblyJarName  := "dispax-server.jar",
    fork                        := true,
    Compile / run / javaOptions ++= Seq(
      "-Djava.util.logging.config.file=logging.properties",
      "-Dcom.sun.management.jmxremote=false",
      "-Djava.rmi.server.randomIDs=true",
      "-Dsun.rmi.transport.tcp.localHostnameTimeOut=2000",
      "-XX:+DisableAttachMechanism",
      "-Djdk.attach.allowAttachSelf=true"
    )
  )
