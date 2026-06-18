# Dispax — Claude Code Instructions

## Project Overview

Dispax is a ride dispatching platform for small and medium-sized transport businesses (taxis, corporate transfers). The MVP targets Munich and its suburbs (up to 100 km). Business clients: time is critical, the client does not wait.

**Roles:** Driver, Client, Secretary, Dispatcher, Admin  
**Multitenancy:** all data is isolated by `CompanyId`  
**Product requirements:** `docs/requirements.md`

---

## Architecture

```
Flutter (web/mobile)
        ↓ HTTPS / WebSocket
    api (ZIO-HTTP, port 8080)
        ↓ ZIO Layers
  ┌─────┬──────┬────────┬──────────┬──────────┬─────────┐
core  auth  ride  driver  schedule  notification  billing
        ↓
  PostgreSQL 16 (Doobie + HikariCP + Flyway)
        ↓
  GCP Cloud Run (europe-west1)
```

**Backend:** Scala 3.3.7 + ZIO 2 + ZIO-HTTP 3 + Doobie + ZIO-JSON  
**Frontend:** Flutter 3.8+ + flutter_bloc + Google Maps + Mapbox + Firebase Messaging  
**Auth:** JWT (stateless) + JBCrypt  
**Push:** Firebase Cloud Messaging  
**Migrations:** Flyway (`api/src/main/resources/db/migration/`)

---

## Module Map

| Module | Purpose |
|--------|-----------|
| `core` | Shared domain: IDs (UUID v7), Location, Person, Company, sessions, DB utils, config |
| `auth` | JWT authentication, user management, rate limiting |
| `ride` | Ride lifecycle: CRUD, driver assignment, status machine, ratings, expenses |
| `driver` | Driver location tracking, proximity calculation |
| `schedule` | Driver schedules (days, shifts, availability) |
| `notification` | Firebase Cloud Messaging, notification orchestration |
| `billing` | Invoices, client companies, DATEV export |
| `api` | HTTP entry point: route aggregation (14 route files), DI wiring in `Application.scala` |
| `web` | Flutter app: BLoC, screens, services, theme, localization (DE/EN/UK) |

---

## Key Patterns

### Layered Architecture (per module)
```
domain/          — pure case classes, enums, value objects (no dependencies)
application/     — services, business logic, validators (ZIO layers)
infrastructure/
  http/          — route handlers + DTO
    dto/         — Request/Response DTO
  repository/    — Doobie + PostgreSQL
```

### ZIO Layers (DI)
All services and repositories are provided via `ZLayer`. The assembly point is `api/src/main/scala/com/shevchyk/Application.scala`.

### Authenticated Routes
Use `authenticatedHandler` / `authenticatedJsonHandler` from the core middleware. The helpers extract JWT claims and `CompanyId` automatically.

### Company Isolation
**Mandatory** for every request: filter data by `CompanyId` from the JWT claims. Breaking isolation is a critical security error.

### Repository Pattern
Trait at the module root → PostgreSQL implementation in `infrastructure/repository/`. For tests, an in-memory implementation lives in `src/test/`.

### Ride Status Machine
```
Requested → Assigned → InProgress → Completed
                     ↘ Cancelled
```
Only rides with the `Requested` status can be assigned to a driver.

### Validation
A `Validator` typeclass with `given` instances for each request DTO. Validation lives in `application/validation/`.

---

## Build & Run

```bash
# Local development
docker-compose up -d          # PostgreSQL on port 5432
make dev                      # Run the server with .env.dev (port 8080)

# Flutter
make flutter-dev              # Run on the connected device (→ local backend)
make flutter-dev-android      # Android emulator
make flutter-dev-ios          # iOS simulator
make dev-all                  # Backend + Flutter on both devices

# Build
sbt assembly                  # Fat JAR → dispax-server.jar
make deploy                   # Build JAR → Docker push → Cloud Run deploy

# Formatting
make fmt                      # Scalafmt
make fmtAll                   # Scala + Dart
```

---

## Testing

```bash
make test                     # Unit + integration (without Cucumber)
make test-bdd                 # Cucumber BDD scenarios
make test-all                 # All tests
make flutter-test-integration # Flutter integration tests → local TestApplication
```

**Strategy:**
- **Unit**: in-memory repository implementations (e.g. `InMemoryRideRepository`, `MockPersonRepository`)
- **Integration**: Testcontainers + a real PostgreSQL — **do not mock the DB in integration tests**
- **BDD**: Cucumber scenarios in `api/src/test/scala/com/shevchyk/app/`
- **Flutter**: `bloc_test` + `mocktail`

**Test data:** the Flyway migration `V1001__Insert_dev_data.sql` (dev environment only)

---

## Business Rules & Constraints

Full requirements: `docs/requirements.md`

**Key constraints:**
1. Companies are isolated — drivers are assigned only to rides of their own company
2. Only a ride with the `Requested` status can be assigned
3. An assignment must reference a valid `ScheduleDay`
4. Travel time is computed via the Google API to validate the schedule
5. The client does not wait — punctuality takes priority over driver utilization
6. Rides are created by: secretary, dispatcher, driver, or client

---

## Coding Conventions

- Scala 3: prefer `given`/`using`, opaque types for IDs, extension methods
- ZIO effect system everywhere — no Future, no `throw`
- DTOs are separated from domain objects; mapping happens in the route handler or application layer
- JSON: ZIO-JSON (`@jsonField`, `JsonDecoder`/`JsonEncoder`) is primary; Circe only where already used
- IDs: UUID v7 (time-ordered) via UUID Creator
- Logging: ZIO Logging (`ZIO.logInfo`, `ZIO.logError`)
- For routes: group public and authenticated endpoints into separate methods within a single route class
- Flutter: BLoC pattern for all state, a `Repository` abstraction for API calls

---

## Environment & Config

```bash
# .env.dev (dev) / env vars in Cloud Run (prod)
DATABASE_URL=jdbc:postgresql://localhost:5432/dispax
DATABASE_USER=dispax
DATABASE_PASSWORD=dispax
JWT_SECRET=dev-secret-change-in-production
APP_ENV=development
PORT=8080
```

**docker-compose.yml** brings up PostgreSQL 16 (port 5432, DB: `dispax`)  
**Production URL:** `https://dispax-o2trzxjbva-ew.a.run.app`  
**API docs (Swagger UI):** `/docs` — OpenAPI document at `/docs/docs.yaml` (YAML only; no JSON variant). Local: `http://localhost:8080/docs`, prod: `https://dispax-o2trzxjbva-ew.a.run.app/docs`. Generated via Tapir `SwaggerInterpreter` in `api/.../app/openapi/OpenApiServer.scala` — single source of truth for all 148 endpoints.  
**CI/CD:** GitHub Actions → push to `main` → sbt assembly → Docker → Cloud Run

---

## Development Workflow

- **Every feature is developed in a separate git worktree** — never commit feature work directly to `main`. Create a dedicated worktree + branch per feature (`git worktree add ../dispax-<feature> -b <branch>`), implement and test there, then merge back into `main`.
- Branch naming: `feat/<name>` for features, `chore/<name>` for maintenance, `agent/<name>` for agent-driven work.
- Run formatting (`make fmt` / `make fmtAll`) and tests (`make test`) inside the worktree before merging.

---

## What NOT to Do

- Do not develop features directly on `main` — always use a separate git worktree
- Do not mock the DB in integration tests — use Testcontainers
- Do not break company isolation (`CompanyId`) in any request
- Do not use `Future` or `throw` — only ZIO effects
- Do not put business logic in route handlers — only in the application layer
- Do not hardcode secrets — only via env vars
