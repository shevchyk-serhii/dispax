# Architecture

## Modules

| Module           | Description                                                                                                                                                             |
|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **core**         | Shared domain: IDs, Location, Person, Company, Sessions, Blacklist, Geofences, GDPR, Audit, CompanySettings, RidePools, EmergencyReassignments, NotificationPreferences |
| **auth**         | Authentication: JWT login, user management, tokens                                                                                                                      |
| **ride**         | Ride lifecycle: CRUD, assignment, status transitions                                                                                                                    |
| **driver**       | Driver location tracking, proximity calculation, HERE routing ETA                                                                                                       |
| **schedule**     | Driver schedule management (daily shifts)                                                                                                                               |
| **notification** | Push notifications (FCM), orchestrator, preferences                                                                                                                     |
| **billing**      | Invoices, client companies, PDF generation, DATEV export                                                                                                                |
| **api**          | HTTP entry point, route aggregation, config, DB migrations                                                                                                              |
| **web**          | Flutter/Dart mobile client (iOS, Android, macOS)                                                                                                                        |
| **landing**      | Next.js marketing/landing site (`landing/`, deployed separately on Vercel; not an sbt module)                                                                           |

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

infrastructure/   DB repositories, external integrations, DTOs
  ├── http/dto/
  └── repository/

openapi/          Tapir endpoint descriptions (HTTP layer)
  ├── XxxApi.scala

middleware/       Cross-cutting HTTP concerns (auth module only)
  ├── AuthMiddleware.scala   JWT extraction / bearer validation
  ├── RateLimiter.scala      per-IP / per-email token-bucket limiting
  └── UuidParser.scala
```

**Domain** — Pure case classes & enums, no framework dependencies. Defines entities (`Ride`, `ScheduleDay`), value objects (`Location`, `PersonId`), status enums, and domain errors.

**Application** — ZIO services that implement business rules. Each service is provided as a `ZLayer` for DI. Validators use typeclass-based validation.

**Infrastructure** — Doobie-based PostgreSQL repositories and DTO conversions. The HTTP layer is described declaratively with **Tapir** endpoints in `openapi/XxxApi.scala` (one per resource, ~32 in total) — the single source of truth for routing and the `/docs` OpenAPI/Swagger document. Endpoints derive from a shared `secureBase` that validates the bearer token; public endpoints are described separately (no `securityIn`). A few infrastructure-only routes remain as ZIO-HTTP handlers under `api/.../app/routes/` (health, WebSocket, dev, guest-tracking page).

## Key Patterns

- **Repository pattern** — trait in module root, PostgreSQL implementation in infrastructure
- **ZIO Layers for DI** — all services/repos wired via `ZLayer.provide` in `Application.scala`
- **Company isolation (multi-tenancy)** — most queries are scoped by `CompanyId`; enforced at service and route level
- **Authenticated vs public endpoints** — a shared Tapir `secureBase` validates the bearer token via `zServerSecurityLogic` and yields an `AuthenticatedUser` (incl. `companyId` from the JWT payload); public endpoints are described without `securityIn`
- **Typeclass validation** — `Validator` typeclass with `given` instances per request DTO
- **Rate limiting** — token-bucket `RateLimiter` (`auth/.../middleware/`) throttles login by IP and by email, and password-change per user

## Directory Structure

```
dispax/
├── api/src/main/scala/com/shevchyk/    # Root module (entry point)
│   ├── Application.scala               # Main, route aggregation, DI wiring
│   ├── app/routes/                     # Infra routes: health, WebSocket, dev, track page
│   ├── app/openapi/OpenApiServer.scala # Tapir → OpenAPI/Swagger at /docs
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
