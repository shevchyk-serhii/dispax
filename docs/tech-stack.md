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
| Firebase Admin  | 9.3.0     | Push notifications (FCM)       |
| JBCrypt         | 0.4       | Password hashing               |

## Frontend

| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter/Dart | 3.8.1+ | Cross-platform mobile app |
| flutter_bloc | 8.1.6 | State management (BLoC pattern) |
| google_maps_flutter | 2.2.0 | Google Maps integration |
| mapbox_maps_flutter | 2.4.0 | Mapbox maps |
| geolocator | 13.0.1 | GPS location services |
| firebase_messaging | 15.1.6 | Push notifications |
| web_socket_channel | 3.0.1 | Real-time WebSocket updates |
| flutter_secure_storage | 9.2.2 | Secure token storage |
| local_auth | 2.1.6 | Biometric authentication |
| table_calendar | 3.1.2 | Calendar widget |
| intl | 0.20.2 | Internationalization (DE, EN, UK) |

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
| Testcontainers  |         | PostgreSQL integration tests   |
| bloc_test       | 9.1.7   | BLoC testing utilities         |
| mocktail         | 1.0.4   | Mocking library (Flutter)     |

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
