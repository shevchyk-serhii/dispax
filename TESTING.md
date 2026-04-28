# Testing Setup

## Test Framework

- **ZIO Test** — Primary unit/integration test framework
- **Cucumber 7.15.0** — BDD acceptance tests
- **Testcontainers** — PostgreSQL integration tests

## Test Architecture

**Production (main sources):**
- `PersonRepository` — PostgreSQL implementation
- `TokenRepository` — PostgreSQL implementation
- `AuthService`, `RideService`, etc. — ZIO service layers

**Testing (test sources):**
- `MockPersonRepository` — in `core/src/test/scala/`
- `InMemoryTokenRepository` — in `auth/src/test/scala/`
- In-memory implementations for all repositories used in unit tests

## Running Tests

```bash
# Unit tests (ZIO Test)
sbt test

# BDD acceptance tests (Cucumber)
sbt cucumber

# Run development server with test data
sbt runDev
```

Development mode (`sbt runDev`) loads test data via Flyway dev migration: `api/src/main/resources/db/migration-dev/V1001__Insert_dev_data.sql`

## Test Data

Test data is seeded via Flyway dev migration (V1001) and includes sample persons, companies, rides, and schedules with UUID identifiers. Authentication uses JWT tokens generated at login.

## Test Coverage

| Module | Coverage | Notes |
|--------|----------|-------|
| auth | ~80% | JWT, AuthService, RateLimiter, integration |
| ride | ~60% | Service, domain, API, statistics |
| core | ~50% | Geofence, domain, person repo |
| schedule | ~40% | Service only |
| notification | ~30% | Orchestrator only |
| driver | ~20% | No dedicated tests |

## Test Principles

1. **Clean Architecture**: production code does not contain test data
2. **Fast Tests**: in-memory implementations for unit tests
3. **Predictability**: test data via Flyway migration is always the same
4. **Isolation**: unit tests do not depend on database state
5. **Integration**: Testcontainers for DB-dependent tests
