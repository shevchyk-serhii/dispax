# Architecture

## Modules

| Module         | Description                                         |
|----------------|-----------------------------------------------------|
| **core**       | Shared domain: IDs, Location, Person, Company, Sessions, Blacklist, Geofences, GDPR, Audit, CompanySettings, RidePools, EmergencyReassignments, NotificationPreferences       |
| **auth**       | Authentication: JWT login, user management, tokens  |
| **ride**       | Ride lifecycle: CRUD, assignment, status transitions |
| **driver**     | Driver location tracking, proximity calculation, HERE routing ETA     |
| **schedule**   | Driver schedule management (daily shifts)            |
| **notification** | Push notifications (FCM), orchestrator, preferences                |
| **billing**    | Invoices, client companies, PDF generation, DATEV export |
| **api**        | HTTP entry point, route aggregation, config, DB migrations |
| **web** | Flutter/Dart mobile client (iOS, Android, macOS)                          |

## Module Dependencies

```
api (root)
 ├── core
 ├── auth        → core
 ├── ride        → core, auth
 ├── driver      → core, auth, ride
 ├── schedule    → core, auth
 ├── notification → core
 └── billing     → core, auth, ride
```

## Layered Architecture (Onion / Hexagonal)

Each module follows the same layered structure:

```
domain/           Entities, value objects, enums, error types
  ├── XxxDomain.scala

application/      Services, business logic, validators
  ├── XxxService.scala
  ├── validation/

infrastructure/   HTTP routes, DB repositories, external integrations
  ├── http/
  │   ├── XxxRoutes.scala
  │   └── dto/
  └── repository/
```

**Domain** — Pure case classes & enums, no framework dependencies. Defines entities (`Ride`, `ScheduleDay`), value objects (`Location`, `PersonId`), status enums, and domain errors.

**Application** — ZIO services that implement business rules. Each service is provided as a `ZLayer` for DI. Validators use typeclass-based validation.

**Infrastructure** — ZIO-HTTP route handlers, Doobie-based PostgreSQL repositories, DTO conversions. Routes are split into public and authenticated (JWT middleware).

## Key Patterns

- **Repository pattern** — trait in module root, PostgreSQL implementation in infrastructure
- **ZIO Layers for DI** — all services/repos wired via `ZLayer.provide` in `Application.scala`
- **Company isolation (multi-tenancy)** — most queries are scoped by `CompanyId`; enforced at service and route level
- **Authenticated vs public routes** — `AuthMiddleware` extracts JWT claims; `authenticatedHandler` / `authenticatedJsonHandler` helpers
- **Typeclass validation** — `Validator` typeclass with `given` instances per request DTO

## Directory Structure

```
oktopus/
├── api/src/main/scala/com/shevchyk/    # Root module (entry point)
│   ├── Application.scala               # Main, route aggregation, DI wiring
│   ├── app/routes/UserRoutes.scala
│   ├── config/, database/, repository/
│   └── resources/db/migration/          # Flyway migrations
├── core/src/main/scala/.../core/domain/ # CoreDomain.scala
├── auth/src/main/scala/.../auth/        # domain, application, infrastructure
├── ride/src/main/scala/.../ride/        # domain, application, infrastructure
├── driver/src/main/scala/.../driver/    # domain, application, infrastructure
├── schedule/src/main/scala/.../schedule/
├── notification/src/main/scala/.../notification/
├── billing/src/main/scala/.../billing/  # domain, application, infrastructure
├── web/                                 # Flutter mobile app
├── docs/                                # Documentation
└── build.sbt                            # SBT multi-module build
```
