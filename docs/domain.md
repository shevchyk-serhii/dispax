# Domain Model

## Core Entities

### Person
Central user entity shared across modules.

| Field         | Type               | Notes                    |
|---------------|--------------------|--------------------------|
| id            | `PersonId` (UUID)  | Time-ordered UUID v7     |
| name          | String             |                          |
| email         | String             |                          |
| role          | `PersonRole`       |                          |
| companyId     | Option[CompanyId]  | Multi-tenancy link       |
| licenseNumber | Option[String]     | For drivers              |
| phone         | Option[String]     |                          |

### Company
Tenant entity for multi-tenancy isolation.

| Field   | Type                | Notes |
|---------|---------------------|-------|
| id      | `CompanyId` (UUID)  |       |
| name    | String              |       |
| email   | String              |       |
| phone   | String              |       |
| address | String              |       |

### Ride
Core business entity representing a transport request.

| Field           | Type                  | Notes                        |
|-----------------|-----------------------|------------------------------|
| id              | `RideId` (UUID)       |                              |
| clientId        | `PersonId`            |                              |
| creatorId       | `PersonId`            |                              |
| companyId       | `CompanyId`           | Company isolation            |
| driverId        | Option[PersonId]      | Set on assignment            |
| status          | `RideStatus`          | Default: Requested           |
| pickupLocation  | `Location`            |                              |
| dropoffLocation | `Location`            |                              |
| scheduledTime   | Option[Instant]       |                              |
| requestTime     | Instant               |                              |
| startTime       | Option[Instant]       | Set when InProgress          |
| endTime         | Option[Instant]       | Set when Completed           |
| tariffId        | Option[TariffId]      |                              |
| estimatedPrice  | Option[BigDecimal]    |                              |
| finalPrice      | Option[BigDecimal]    |                              |
| notes           | Option[String]        |                              |
| specifics       | Option[RideSpecifics] | e.g. AirportTransfer         |

### ScheduleDay
Represents a driver's work shift for a specific day.

| Field     | Type                | Notes            |
|-----------|---------------------|------------------|
| id        | `ScheduleDayId`     |                  |
| driverId  | `PersonId`          |                  |
| companyId | `CompanyId`         | Company-scoped   |
| date      | LocalDate           |                  |
| startTime | LocalTime           |                  |
| endTime   | LocalTime           |                  |
| status    | `ScheduleDayStatus` |                  |
| notes     | Option[String]      |                  |

### DriverLocation
Real-time GPS position of a driver.

| Field     | Type       | Notes                                |
|-----------|------------|--------------------------------------|
| driverId  | `PersonId` |                                      |
| latitude  | Double     |                                      |
| longitude | Double     |                                      |
| updatedAt | Instant    | Haversine distance calculation available |

## Value Objects / IDs

All IDs are UUID-based wrappers using time-ordered epoch UUIDs (`UuidCreator.getTimeOrderedEpoch()`):

`PersonId`, `CompanyId`, `RideId`, `TariffId`, `ScheduleDayId`

### Location

| Field     | Type            |
|-----------|-----------------|
| address   | String          |
| latitude  | Option[Double]  |
| longitude | Option[Double]  |

## Enums

### PersonRole
`Driver` | `Client` | `Secretary` | `Dispatcher`

### RideStatus
`Requested` | `Assigned` | `InProgress` | `Completed` | `Cancelled`

### DriverStatus
`Available` | `Busy` | `Offline`

### ScheduleDayStatus
`Scheduled` | `Active` | `Completed` | `Cancelled`

### UserRole (auth module)
`CLIENT` | `DRIVER` | `DISPATCHER` | `SECRETARY` | `ADMIN`

### UserStatus (auth module)
`ACTIVE` | `INACTIVE` | `SUSPENDED`

## RideSpecifics

Sealed trait for ride-type-specific data, stored as JSONB in PostgreSQL.

- **AirportTransfer** — `airportCode: String`, `flightNumber: String`

## Ride Lifecycle

```
Requested ──→ Assigned ──→ InProgress ──→ Completed
    │              │             │
    └──────────────┴─────────────┴──→ Cancelled
```

- `canBeAssigned`: status == Requested
- `canBeStarted`: status == Assigned && driverId is set
- `canBeCompleted`: status == InProgress

## Key Business Rules

- **Company isolation** — rides, schedules, and assignments are scoped to a company. Enforced at both service and route layers.
- **Assignment rules** — only `Requested` rides can be assigned; driver must exist and be valid.
- **Driver proximity** — Haversine formula calculates distance in meters between driver and pickup location (see `DriverLocation.distanceMeters`).
- **Schedule uniqueness** — one schedule day per driver per date within a company.
- **Status transitions** — invalid transitions raise `InvalidStatusTransition` errors.
