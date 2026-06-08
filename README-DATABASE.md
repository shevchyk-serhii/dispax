# Database Setup

## PostgreSQL with Doobie

PostgreSQL is the sole persistence layer. Schema is managed by Flyway migrations.

### Architecture

- **Domain Layer**: Repository interfaces (ports)
- **Infrastructure Layer**: PostgreSQL implementations via Doobie (adapters)
- **Application Layer**: Business services using repository contracts

### Setup

1. Start PostgreSQL:
```bash
docker-compose up -d postgres
```

2. Run in development mode:
```bash
sbt runDev
```

3. Run in production mode:
```bash
sbt runProd
```

Flyway migrations run automatically on startup.

### Database Schema

Managed by Flyway in `api/src/main/resources/db/migration/`:

| Migration | Description |
|-----------|-------------|
| V1__Create_schema.sql | Full consolidated schema: persons (incl. `reminder_minutes`), companies, rides, `sent_reminders`, drivers, tariffs, schedules, notifications, chat, ratings, expenses, geofences, blacklist, GDPR, audit, sessions, pools, invoices |

Development data: `api/src/main/resources/db/migration-dev/V1001__Insert_dev_data.sql` (loaded only in development profile).

### Configuration

Base config in `api/src/main/resources/application.conf`:

```hocon
database {
  driver = "org.postgresql.Driver"
  url = "jdbc:postgresql://localhost:5432/dispax"
  user = "dispax"
  password = "dispax"
  maxPoolSize = 10
  minIdle = 2
}
```

Environment variable overrides:
- `DATABASE_URL`
- `DATABASE_USER`
- `DATABASE_PASSWORD`

Production profile (`application-production.conf`) increases pool sizes: maxPoolSize=20, minIdle=5.

### Environment Profiles

| Profile | Config file | Test data | Pool size |
|---------|------------|-----------|-----------|
| development | application-development.conf | Yes (V1001) | 10/2 |
| production | application-production.conf | No | 20/5 |

### Testing

- Unit tests use in-memory repository implementations (in test sources)
- Integration tests use Testcontainers (PostgreSQL)
- Development mode loads test data via Flyway dev migration

### Repository Implementations

- `PostgresPersonRepository` — Person CRUD, search, role/status filtering
- `PostgresRideRepository` — Ride persistence, status queries, assignment
- `PostgresDriverLocationRepository` — Driver GPS location tracking
- `PostgresScheduleDayRepository` — Driver schedule management
- `PostgresRideRatingRepository` — Ride ratings
- `PostgresChatMessageRepository` — In-ride chat
- `PostgresExpenseRepository` — Driver expenses
- `PostgresRideTemplateRepository` — Recurring ride templates
- `PostgresClientLocationRepository` — Client location sharing
- `PostgresNotificationRepository` — Push notifications
- `PostgresFcmTokenRepository` — Firebase device tokens
- `PostgresSessionRepository` — User sessions
- `PostgresBlacklistRepository` — Client-driver blacklist
- `PostgresGeofenceRepository` — Geofence zones
- `PostgresGdprRepository` — GDPR consents and requests
- `PostgresCompanySettingsRepository` — Company configuration
- `PostgresRidePoolRepository` — Ride pooling
- `PostgresEmergencyReassignmentRepository` — Emergency reassignments
- `PostgresNotificationPreferenceRepository` — Notification preferences
- `PostgresAuditService` — Audit trail

All repositories implement domain interfaces and use Doobie's parameterized queries for SQL injection protection.
