# Tech Stack

## Backend

| Technology        | Version   | Purpose                          |
|-------------------|-----------|----------------------------------|
| Scala             | 3.3.7     | Language                         |
| ZIO               | 2.1.9     | Effect system, concurrency, DI   |
| ZIO-HTTP          | 3.0.1     | HTTP server & routing            |
| ZIO-JSON          | 0.7.3     | JSON serialization               |
| ZIO-Config        | 4.0.2     | Typesafe configuration           |
| ZIO-Logging       | 2.3.1     | SLF4J logging bridge             |
| Doobie            | 1.0.0-RC5 | JDBC / SQL (functional)          |
| PostgreSQL driver | 42.7.4    | Database driver                  |
| Flyway            | 10.20.1   | Database migrations              |
| Circe             | 0.14.10   | JSON (for JSONB / Doobie codecs) |
| Monocle           | 3.3.0     | Optics / lenses                  |
| JWT-Scala         | 10.0.1    | JWT authentication               |
| UUID Creator      | 5.3.2     | Time-ordered UUID v7 generation  |
| ZIO-Interop-Cats  | 23.1.0.3  | Cats interop (Doobie bridge)     |
| Logback           | 1.5.15    | Logging implementation           |

## Frontend

| Technology | Purpose                        |
|------------|--------------------------------|
| Flutter/Dart | Cross-platform mobile app    |
| Mapbox     | Map rendering & navigation     |
| BLoC       | State management pattern       |

## Build & Tooling

| Tool       | Purpose                                |
|------------|----------------------------------------|
| SBT        | Build tool, multi-module project       |
| sbt-assembly | Fat JAR packaging                   |
| Scalafmt   | Code formatting                        |
| Dart format | Flutter code formatting               |

## Testing

| Technology      | Version | Purpose                        |
|-----------------|---------|--------------------------------|
| ZIO Test        | 2.1.9   | Unit / integration tests       |
| Cucumber        | 7.15.0  | BDD acceptance tests           |
| Cucumber-Scala  | 8.20.0  | Scala step definitions         |
| JUnit           | 4.13.2  | Test runner bridge             |

Testing approach: Cucumber BDD scenarios with in-memory repository implementations for isolated testing.

## SBT Modules

```
root (api)
├── core           — shared domain, DB utils, config
├── auth           → core
├── ride           → core, auth
├── driver         → core, auth, ride
├── schedule       → core, auth
└── notification   → core
```

## Useful SBT Commands

| Command            | Description                          |
|--------------------|--------------------------------------|
| `sbt run`          | Run with default config              |
| `sbt runDev`       | Run with development config          |
| `sbt runProd`      | Run with production config           |
| `sbt cucumber`     | Run Cucumber BDD tests               |
| `sbt fmt`          | Format Scala code                    |
| `sbt assembly`     | Build fat JAR (`oktopus-server.jar`) |
