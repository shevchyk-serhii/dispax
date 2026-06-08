# Dispax

> Multi-tenant ride-dispatch platform for small and medium transport businesses (taxi, corporate transfers).

![Scala](https://img.shields.io/badge/Scala-3.3.7-DC322F?logo=scala&logoColor=white)
![ZIO](https://img.shields.io/badge/ZIO-2.1.9-FF6B6B)
![Flutter](https://img.shields.io/badge/Flutter-3.8+-02569B?logo=flutter&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

Dispax dispatches rides for time-critical transport operators where punctuality beats driver
utilization — the client does not wait. Every piece of data is isolated per tenant (`CompanyId`),
and the system is built end-to-end on a pure functional, effect-based Scala backend with a
Flutter cross-platform frontend.

---

## Overview

- **Domain:** ride dispatching for taxis and corporate transfers (MVP scoped to Munich and surroundings, up to 100 km).
- **Roles:** Driver, Client, Secretary, Dispatcher, Admin.
- **Multi-tenancy:** strict isolation — every request is filtered by `CompanyId` from JWT claims.
- **Ride lifecycle:** a typed status machine governs every transition (see below).

---

## Tech Stack

**Backend**
- Scala 3.3.7 · ZIO 2.1.9 (pure FP, effect system — no `Future`, no `throw`)
- ZIO-HTTP 3.0.1 · ZIO-JSON 0.7.3 · ZIO Config
- Doobie (typed SQL) · HikariCP · Flyway migrations
- Monocle 3.3 (optics) · jwt-scala (stateless JWT) · JBCrypt

**Frontend**
- Flutter 3.8+ · flutter_bloc (BLoC state management)
- Google Maps · Mapbox (geocoding) · Firebase Cloud Messaging (push)
- Localization: DE / EN / UK (`web/lib/l10n/`)

**Data & Infrastructure**
- PostgreSQL 16
- Docker / docker-compose for local dev
- GCP Cloud Run (europe-west1)
- CI/CD via GitHub Actions (sbt assembly → Docker → Cloud Run)

---

## Architecture

```
Flutter (web / mobile)
        ↓ HTTPS / WebSocket
    api (ZIO-HTTP, port 8080)
        ↓ ZIO Layers (DI)
  ┌─────┬──────┬──────┬────────┬──────────┬──────────────┬─────────┐
 core  auth  ride  driver  schedule  notification     billing
        ↓
  PostgreSQL 16 (Doobie + HikariCP + Flyway)
```

Each module follows a **layered / hexagonal** structure:

```
domain/          pure case classes, enums, value objects (no dependencies)
application/     services, business logic, validators (ZIO layers)
infrastructure/
  http/          route handlers + DTOs
  repository/    Doobie + PostgreSQL
```

Dependency injection is wired entirely through `ZLayer`, with the assembly point in
`api/src/main/scala/com/shevchyk/Application.scala`. The HTTP surface aggregates 14 route files.

Further reading: [`docs/architecture.md`](docs/architecture.md) ·
[`docs/domain.md`](docs/domain.md) · [`docs/database-schema.svg`](docs/database-schema.svg) ·
[`docs/tech-stack.md`](docs/tech-stack.md)

---

## Key Engineering Highlights

- **Strict multi-tenant isolation** — every query is scoped to the `CompanyId` extracted from JWT
  claims; cross-tenant access is treated as a critical security violation.
- **Typed ride status machine** — only `Requested` rides can be assigned to a driver:
  ```
  Requested → Assigned → InProgress → Completed
                       ↘ Cancelled
  ```
- **Typeclass-based validation** — a `Validator` typeclass with `given` instances per request DTO,
  keeping validation declarative and decoupled from route handlers.
- **Pure functional core** — ZIO effects throughout; opaque types for IDs; time-ordered UUID v7.
- **Repository pattern** — a trait per module with a PostgreSQL implementation in
  `infrastructure/repository/` and in-memory implementations for unit tests.
- **Layered testing strategy:**
  - **Unit** — in-memory repositories (e.g. `InMemoryRideRepository`).
  - **Integration** — Testcontainers against a real PostgreSQL (the DB is never mocked).
  - **BDD** — Cucumber scenarios.
  - **Flutter** — `bloc_test` + `mocktail`.

---

## Getting Started

```bash
# 1. Start PostgreSQL (port 5432)
docker-compose up -d

# 2. Configure environment — copy the template and fill in values
cp .env.example .env.dev

# 3. Run the backend (port 8080)
make dev

# 4. Run the Flutter app on a connected device
make flutter-dev          # or flutter-dev-android / flutter-dev-ios
```

Database details: [`README-DATABASE.md`](README-DATABASE.md).

---

## Testing

```bash
make test                     # unit + integration (Testcontainers)
make test-bdd                 # Cucumber BDD scenarios
make test-all                 # everything
make flutter-test-integration # Flutter integration tests
```

Formatting:

```bash
make fmt       # Scalafmt
make fmtAll    # Scala + Dart
```

---

## Project Structure

| Module         | Purpose                                                                       |
| -------------- | ----------------------------------------------------------------------------- |
| `core`         | Shared domain: IDs (UUID v7), Location, Person, Company, sessions, DB & config |
| `auth`         | JWT authentication, user management, rate limiting                            |
| `ride`         | Ride lifecycle: CRUD, driver assignment, status machine, ratings, expenses    |
| `driver`       | Driver location tracking and proximity calculation                            |
| `schedule`     | Driver schedules (days, shifts, availability)                                 |
| `notification` | Firebase Cloud Messaging, notification orchestration                          |
| `billing`      | Invoices, client companies, DATEV export                                      |
| `api`          | HTTP entry point: route aggregation and DI wiring                             |
| `web`          | Flutter app: BLoC, screens, services, theming, localization                   |

---

## License

[MIT](LICENSE) © 2025 Serhii Shevchyk
