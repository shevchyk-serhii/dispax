# Dev Flow — Project Config

> Source of project-specific truth for the dev-flow plugin. All flow agents read it.
> Regenerate with `/dev-flow:dev-flow-init`.

## Domain

Dispax is a ride-dispatching platform for small and medium transport businesses (taxis, corporate
transfers); MVP targets Munich and suburbs (up to 100 km). Roles: Driver, Client, Secretary,
Dispatcher, Admin. Punctuality is the priority — the client does not wait, even at the cost of driver
utilization. All data is multi-tenant, isolated by `CompanyId`. Rides may be created by a secretary,
dispatcher, driver, or client. Full requirements: `docs/requirements.md`.

## Main branch

`master`

## Stack

Scala 3.3.7 + ZIO 2 + ZIO-HTTP 3 + Doobie (PostgreSQL 16), sbt build, JWT auth.
Flutter 3.8+ frontend (flutter_bloc, Google Maps/Mapbox, Firebase Messaging). Deploy: GCP Cloud Run.

## Module / layer map

Modules: `core auth ride driver schedule notification billing api web`.
Per-module layering: `domain/` (pure case classes/enums, value objects) → `application/` (services,
business logic, validators as ZIO layers) → `infrastructure/{http,repository}/`
(http: route handlers + DTOs; repository: Doobie + PostgreSQL).
DI assembly point: `api/src/main/scala/com/shevchyk/Application.scala`.

## Gate commands

- build/compile: `sbt compile`
- format: `make fmt`   (= `sbt fmtAll`)
- test: `make test`   (per-module backend: core, auth, ride, driver, notification, schedule)
  - acceptance/BDD when `api` is touched: `make test-bdd`
  - Flutter integration when `web` is touched: `make flutter-test-integration`

## Testing strategy

ZIO Test (unit/integration) + Cucumber 7 (BDD) + Testcontainers (DB).
- Unit: in-memory repository doubles — templates `MockPersonRepository` (`core/src/test/`),
  `InMemoryTokenRepository` (`auth/src/test/`).
- Integration: real PostgreSQL via Testcontainers — **never mock the DB**.
- BDD: Cucumber scenarios in `api/src/test/scala/com/shevchyk/app/`.
- Test data: Flyway dev migration `V1001__Insert_dev_data.sql` (dev only).
- Low-coverage areas to prioritize: driver (~20%), notification (~30%), schedule (~40%).
- **Required test types** — a unit test (in-memory double) for every new business branch in the
  application layer; an integration test (Testcontainers + real PostgreSQL) when a repository or HTTP
  boundary changes; a Cucumber BDD scenario per acceptance criterion when `api` routes change.
- **Minimum coverage** — every new public service method and every acceptance criterion of the change
  is exercised; tenant isolation (filtering by `CompanyId`) must have an explicit negative test on any
  touched endpoint. No project-wide coverage percentage bar.

## Conventions

- Scala 3: `given`/`using`, opaque types for IDs (UUID v7 via UUID Creator), extension methods.
- ZIO-only effects; ZIO Logging (`ZIO.logInfo`, `ZIO.logError`).
- DTOs separated from domain; mapping in handler/application layer.
- JSON: ZIO-JSON (`@jsonField`, `JsonDecoder`/`JsonEncoder`) primary; Circe only where already used.
- Authenticated routes: `authenticatedHandler` / `authenticatedJsonHandler` (provide JWT claims + CompanyId).
- Repository: trait at module root → PostgreSQL impl in `infrastructure/repository/`.
- Validation: `Validator` typeclass with `given` instances in `application/validation/`.

## Invariants

1. **Tenant isolation** [CRITICAL/SECURITY] — every request filters data by `CompanyId` from JWT claims.
   Drivers are assigned only to rides of their own company.
2. **ZIO-only** — no `Future`, no `throw`; only ZIO effects.
3. **Clean handlers** — no business logic in route handlers; it lives in the application layer.
4. **Integration tests** — never mock the DB; use Testcontainers.
5. **Secrets** — env vars only, never hardcoded.
6. **DTO ≠ domain** — DTOs separated; mapping in handler/application layer.
7. **Ride status machine** — `Requested → Assigned → InProgress → Completed` (or `→ Cancelled`);
   a driver may be assigned only to a ride in `Requested` status. An assignment must reference a valid
   `ScheduleDay`.
