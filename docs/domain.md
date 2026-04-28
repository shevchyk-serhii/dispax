# Domain Model

## Core Entities

### Person
Central user entity (auth + business data merged into single table since V6 migration).

| Field | Type | Notes |
|-------|------|-------|
| id | `PersonId` (UUID) | Time-ordered UUID v7 |
| name | String | |
| email | String | Unique |
| passwordHash | String | BCrypt, cost 12 |
| role | `PersonRole` | |
| status | String | ACTIVE, INACTIVE, SUSPENDED |
| companyId | Option[CompanyId] | Multi-tenancy link |
| licenseNumber | Option[String] | For drivers |
| phone | Option[String] | |
| vehicleInfo | Option[VehicleInfo] | Make, model, color, plate, year |
| isVip | Option[Boolean] | VIP client flag |
| preferredDriverId | Option[PersonId] | Preferred driver for client |

### Company
Tenant entity for multi-tenancy isolation.

| Field | Type | Notes |
|-------|------|-------|
| id | `CompanyId` (UUID) | |
| name | String | |
| email | String | |
| phone | String | |
| address | String | |

### Ride
Core business entity representing a transport request.

| Field | Type | Notes |
|-------|------|-------|
| id | `RideId` (UUID) | |
| clientId | `PersonId` | |
| creatorId | `PersonId` | |
| companyId | `CompanyId` | Company isolation |
| driverId | Option[PersonId] | Set on assignment |
| scheduleDayId | Option[ScheduleDayId] | Linked schedule |
| status | `RideStatus` | Default: Requested |
| pickupLocation | `Location` | |
| dropoffLocation | `Location` | |
| scheduledTime | Option[Instant] | |
| requestTime | Instant | |
| startTime | Option[Instant] | Set when InProgress |
| endTime | Option[Instant] | Set when Completed |
| tariffId | Option[TariffId] | |
| estimatedPrice | Option[BigDecimal] | |
| finalPrice | Option[BigDecimal] | |
| notes | Option[String] | |
| specialRequirements | Option[String] | |
| specifics | Option[RideSpecifics] | e.g. AirportTransfer |
| paymentStatus | Option[PaymentStatus] | |
| paymentMethod | Option[PaymentMethod] | |
| paidAt | Option[Instant] | |
| poolId | Option[RidePoolId] | Pool ride grouping |
| cancellationReason | Option[String] | |

### ScheduleDay
Represents a driver's work shift for a specific day.

| Field | Type | Notes |
|-------|------|-------|
| id | `ScheduleDayId` | |
| driverId | `PersonId` | |
| companyId | `CompanyId` | Company-scoped |
| date | LocalDate | |
| startTime | LocalTime | |
| endTime | LocalTime | |
| status | `ScheduleDayStatus` | |
| notes | Option[String] | |

### DriverLocation
Real-time GPS position of a driver.

| Field | Type | Notes |
|-------|------|-------|
| driverId | `PersonId` | |
| latitude | Double | |
| longitude | Double | |
| updatedAt | Instant | Haversine distance available |

### ChatMessage
In-ride messaging between driver and client.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| rideId | `RideId` | |
| senderId | `PersonId` | |
| message | String | |
| sentAt | Instant | |

### RideRating
Post-ride feedback from client.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| rideId | `RideId` | |
| rating | Int | 1-5 stars |
| comment | Option[String] | |
| createdAt | Instant | |

### Expense
Driver expense tracking.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| driverId | `PersonId` | |
| companyId | `CompanyId` | |
| category | String | fuel, maintenance, etc. |
| amount | BigDecimal | |
| description | Option[String] | |
| date | LocalDate | |

### RideTemplate
Recurring ride definition.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| companyId | `CompanyId` | |
| clientId | `PersonId` | |
| pickupLocation | `Location` | |
| dropoffLocation | `Location` | |
| recurrencePattern | String | DAILY, WEEKLY, etc. |
| isActive | Boolean | |

### RidePool
Group of rides sharing a driver.

| Field | Type | Notes |
|-------|------|-------|
| id | `RidePoolId` | |
| companyId | `CompanyId` | |
| driverId | Option[PersonId] | |
| status | String | |
| maxCapacity | Int | |

### Notification

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| personId | `PersonId` | |
| companyId | `CompanyId` | |
| type | String | |
| title | String | |
| body | String | |
| isRead | Boolean | |
| createdAt | Instant | |

### Session

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| personId | `PersonId` | |
| deviceInfo | Option[String] | |
| createdAt | Instant | |

### BlacklistEntry

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| companyId | `CompanyId` | |
| clientId | `PersonId` | |
| driverId | `PersonId` | |
| reason | Option[String] | |

### CompanySettings

| Field | Type | Notes |
|-------|------|-------|
| companyId | `CompanyId` | |
| commissionPercent | Option[BigDecimal] | |
| currency | Option[String] | |
| workingHoursStart | Option[String] | |
| workingHoursEnd | Option[String] | |

### Geofence

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| companyId | `CompanyId` | |
| name | String | |
| latitude | Double | Center point |
| longitude | Double | Center point |
| radiusMeters | Double | |

### AuditLog

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| companyId | `CompanyId` | |
| entityType | String | |
| entityId | String | |
| action | String | |
| performedBy | `PersonId` | |
| changes | Option[String] | JSON diff |
| createdAt | Instant | |

## Value Objects / IDs

All IDs are UUID-based wrappers using time-ordered epoch UUIDs (`UuidCreator.getTimeOrderedEpoch()`):

`PersonId`, `CompanyId`, `RideId`, `TariffId`, `ScheduleDayId`, `RidePoolId`

### Location

| Field | Type |
|-------|------|
| address | String |
| latitude | Option[Double] |
| longitude | Option[Double] |

### VehicleInfo

| Field | Type |
|-------|------|
| make | Option[String] |
| model | Option[String] |
| color | Option[String] |
| licensePlate | Option[String] |
| year | Option[Int] |

## Enums

### PersonRole
`Driver` | `Client` | `Secretary` | `Dispatcher` | `Admin`

### RideStatus
`Requested` | `Assigned` | `InProgress` | `Completed` | `Cancelled`

### DriverStatus
`Available` | `Busy` | `Offline`

### ScheduleDayStatus
`Scheduled` | `Active` | `Completed` | `Cancelled`

### PaymentStatus
`Unpaid` | `Pending` | `Paid`

### PaymentMethod
`Cash` | `Card` | `Invoice` | `Bank` | `Receivable`

## RideSpecifics

Sealed trait for ride-type-specific data, stored as JSONB in PostgreSQL.

- **AirportTransfer** — `airportCode`, `flightNumber`, `flightTime`, `isArrival`, `gate`, `terminal`

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

- **Company isolation** — rides, schedules, and assignments are scoped to a company
- **Assignment rules** — only `Requested` rides can be assigned; driver must exist and be valid
- **Driver proximity** — Haversine formula calculates distance in meters
- **Schedule uniqueness** — one schedule day per driver per date within a company
- **Status transitions** — invalid transitions raise `InvalidStatusTransition` errors
- **Blacklist** — blacklisted client-driver pairs cannot be assigned
- **Preferred driver** — VIP clients can have a preferred driver
