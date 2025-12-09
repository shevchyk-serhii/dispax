ThisBuild / version      := "0.1.0-SNAPSHOT"
ThisBuild / scalaVersion := "3.3.7"

addCommandAlias("fmt", "; scalafmt ; scalafmtSbt")
addCommandAlias("fmtDart", "! dart format /Users/shevchyk/projects/private/oktopus/app/lib/ --set-exit-if-changed")
addCommandAlias("fmtAll", "; fmt ; fmtDart")
addCommandAlias("fmtWatch", "~fmtAll")

// Common dependencies used across modules
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

lazy val dbDependencies = Seq(
  "org.tpolecat"  %% "doobie-core"                % "1.0.0-RC5",
  "org.tpolecat"  %% "doobie-postgres"            % "1.0.0-RC5",
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

// Core module - shared domain models and utilities
lazy val core = (project in file("core"))
  .settings(
    name := "oktopus-core",
    libraryDependencies ++= commonDependencies ++ configDependencies ++ jsonDependencies
  )

// Auth module - authentication and authorization
lazy val auth = (project in file("auth"))
  .dependsOn(core)
  .settings(
    name := "oktopus-auth",
    libraryDependencies ++= commonDependencies ++ httpDependencies ++ dbDependencies
  )

// Ride management module
lazy val ride = (project in file("ride"))
  .dependsOn(core)
  .settings(
    name := "oktopus-ride",
    libraryDependencies ++= commonDependencies ++ httpDependencies ++ dbDependencies ++ jsonDependencies
  )

// Driver management module
lazy val driver = (project in file("driver"))
  .dependsOn(core, ride)
  .settings(
    name := "oktopus-driver",
    libraryDependencies ++= commonDependencies ++ httpDependencies ++ dbDependencies
  )

// Notification module
lazy val notification = (project in file("notification"))
  .dependsOn(core)
  .settings(
    name := "oktopus-notification",
    libraryDependencies ++= commonDependencies
  )

// Main application - aggregates all modules
lazy val root = (project in file("."))
  .aggregate(core, auth, ride, driver, notification)
  .dependsOn(core, auth, ride, driver, notification)
  .settings(
    name                             := "oktopus",
    Compile / scalaSource            := baseDirectory.value / "api" / "src" / "main" / "scala",
    Test / scalaSource               := baseDirectory.value / "api" / "src" / "test" / "scala",
    libraryDependencies ++= commonDependencies ++ httpDependencies ++ dbDependencies ++ configDependencies,
    testFrameworks += new TestFramework("zio.test.sbt.ZTestFramework"),
    Compile / mainClass              := Some("com.shevchyk.Application"),
    assembly / mainClass             := Some("com.shevchyk.Application"),
    assembly / assemblyJarName       := "oktopus-server.jar",
    assembly / assemblyMergeStrategy := {
      case "module-info.class"                     => MergeStrategy.discard
      case "META-INF/io.netty.versions.properties" => MergeStrategy.first
      case x                                       => (assembly / assemblyMergeStrategy).value(x)
    },
    fork                             := true,
    Compile / run / javaOptions ++= Seq(
      "-Djava.util.logging.config.file=logging.properties",
      "-Dcom.sun.management.jmxremote=false",
      "-Djava.rmi.server.randomIDs=true",
      "-Dsun.rmi.transport.tcp.localHostnameTimeOut=2000",
      "-XX:+DisableAttachMechanism",
      "-Djdk.attach.allowAttachSelf=true"
    )
  )
