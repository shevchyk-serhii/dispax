# Database Setup

## PostgreSQL with Doobie

This project now supports both in-memory and PostgreSQL persistence layers.

### Architecture

- **Domain Layer**: Repository interfaces (ports)
- **Infrastructure Layer**: Doobie implementations (adapters)
- **Application Layer**: Business services using repository contracts

### Setup

1. Start PostgreSQL:
```bash
docker-compose up -d postgres
```

2. Run with PostgreSQL:
```bash
USE_POSTGRES=true sbt run
```

3. Run with in-memory (default):
```bash
sbt run
```

### Database Schema

The schema is managed by Flyway migrations in `api/src/main/resources/db/migration/`:

- **V1__Create_tables.sql**: Initial schema with tables for rides, persons, drivers, companies, tariffs

### Configuration

Database configuration is in `application.conf`:

```hocon
database {
  driver = "org.postgresql.Driver"
  url = "jdbc:postgresql://localhost:5432/oktopus"
  user = "oktopus"
  password = "oktopus"
}
```

Environment variables override:
- `DATABASE_URL`
- `DATABASE_USER` 
- `DATABASE_PASSWORD`
- `USE_POSTGRES=true`

### Testing

Tests use in-memory repositories for fast execution.

### Repository Implementations

- `DoobieRideRepository`: Ride persistence with complex queries
- `DoobiePersonRepository`: Person management
- `DoobieDriverRepository`: Driver location and availability tracking
- `DoobieTariffRepository`: Pricing configuration

All repositories implement domain interfaces and handle SQL mapping transparently.