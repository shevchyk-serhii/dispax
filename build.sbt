ThisBuild / version := "0.1.0-SNAPSHOT"

ThisBuild / scalaVersion := "3.3.7"

addCommandAlias("fmt", "scalafmt")

lazy val root = (project in file("api"))
  .settings(
    name := "oktopus",
    libraryDependencies ++= Seq(
      "dev.zio" %% "zio" % "2.1.9",
      "dev.zio" %% "zio-http" % "3.0.1",
      "dev.zio" %% "zio-logging-slf4j2" % "2.3.1",
      "ch.qos.logback" % "logback-classic" % "1.5.15"
    ),
    Compile / mainClass := Some("com.shevchyk.Application"),
    fork := true,
    Compile / run / javaOptions ++= Seq(
      "-Djava.util.logging.config.file=logging.properties",
      "-Dcom.sun.management.jmxremote=false"
    )
  )
