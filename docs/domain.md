# Domain Model

This document reflects the domain code in `*/src/main/scala/.../domain/`. Entity field tables list
the most relevant fields; consult the source for exhaustive detail. Enums are listed in full.

## Core Entities

### Person
Central user entity (auth + business data merged into a single table since the V6 migration).
`core/.../CoreDomain.scala`.

| Field              | Type                    | Notes                                        |
|--------------------|-------------------------|----------------------------------------------|
| id                 | `PersonId` (UUID)       | Time-ordered UUID v7                         |
| name               | String                  |                                              |
| email              | String                  | Unique                                       |
| role               | `PersonRole`            | Primary role                                 |
| roles              | Set[`PersonRole`]       | Full role set (multi-role users)             |
| companyId          | Option[CompanyId]       | Multi-tenancy link                           |
| passwordHash       | String                  | BCrypt                                        |
| licenseNumber      | Option[String]          | For drivers                                  |
| phone              | Option[String]          |                                              |
| isVip              | Boolean                 | VIP client flag                              |
| preferredDriverId  | Option[PersonId]        | Preferred driver for client                  |
| status             | `UserStatus`            | ACTIVE / INACTIVE / SUSPENDED                |
| lastLoginAt        | Option[Instant]         |                                              |
| clientCompanyId    | Option[ClientCompanyId] | B2B client-company membership                |
| reminderMinutes    | Int                     | Ride reminder lead time (default 60)         |
| avatarPresent      | Boolean                 | Whether a profile photo is stored            |
| avatar             | Option[Array[Byte]]     | Profile photo bytes                          |
| avatarContentType  | Option[String]          |                                              |
| preferredLanguage  | Option[String]          | de / en / uk                                 |
| mustChangePassword | Boolean                 | Force password change on next login          |
| provisional        | Boolean                 | Provisional (chat-created) client            |

### Company
Tenant entity for multi-tenancy isolation. `core/.../CoreDomain.scala`.

| Field            | Type               | Notes                       |
|------------------|--------------------|-----------------------------|
| id               | `CompanyId` (UUID) |                             |
| name             | String             |                             |
| email            | String             |                             |
| phone            | String             |                             |
| address          | String             |                             |
| status           | `CompanyStatus`    | Active / Suspended / Trial / Inactive |
| subscriptionPlan | `SubscriptionPlan` | Free / Starter / Professional / Enterprise |
| createdAt        | Instant            |                             |
| updatedAt        | Instant            |                             |

### ClientCompany
A billed B2B client company under one taxi company (VAT id, airport-timing overrides, VIP).
`core/.../CoreDomain.scala`.

### Ride
Core business entity representing a transport request. `ride/.../RideDomain.scala`.

| Field               | Type                    | Notes                                    |
|---------------------|-------------------------|------------------------------------------|
| id                  | `RideId` (UUID)         |                                          |
| clientId            | `PersonId`              |                                          |
| creatorId           | `PersonId`              |                                          |
| companyId           | `CompanyId`             | Company isolation                        |
| driverId            | Option[PersonId]        | Set on assignment                        |
| status              | `RideStatus`            | Default: Requested                       |
| pickupLocation      | `Location`              |                                          |
| dropoffLocation     | `Location`              |                                          |
| pickupDateTime      | Instant                 | Scheduled pickup                         |
| scheduledTime       | Option[Instant]         |                                          |
| requestTime         | Instant                 |                                          |
| startTime           | Option[Instant]         | Set when InProgress                      |
| endTime             | Option[Instant]         | Set when Completed                       |
| tariffId            | Option[TariffId]        |                                          |
| estimatedPrice      | Option[BigDecimal]      |                                          |
| finalPrice          | Option[BigDecimal]      |                                          |
| notes               | Option[String]          |                                          |
| specialRequirements | Option[String]          |                                          |
| specifics           | Option[RideSpecifics]   | e.g. AirportTransfer                     |
| paymentStatus       | `PaymentStatus`         | Default: Unpaid                          |
| paymentMethod       | Option[PaymentMethod]   |                                          |
| paidAt              | Option[Instant]         |                                          |
| cancellationReason  | Option[String]          |                                          |
| cancellationFee     | Option[BigDecimal]      |                                          |
| cancelledBy         | Option[PersonId]        |                                          |
| isVipRide           | Boolean                 |                                          |
| preferredDriverUsed | Boolean                 |                                          |
| poolId              | Option[RidePoolId]      | Pool ride grouping                       |
| scheduleDayId       | Option[UUID]            | Linked schedule day                      |
| invoiceId           | Option[UUID]            | Set once billed                          |
| vehicleClass        | `VehicleClass`          | Business / Van (default Business)        |
| airportCheckpoint   | Option[AirportCheckpoint] | Passenger self-reported checkpoint     |
| flightIsArrival     | Option[Boolean]         |                                          |
| externalDriverId    | Option[ExternalDriverId] | Set when handed off externally          |
| partnerCompanyId    | Option[PartnerCompanyId] |                                          |
| confirmedAt         | Option[Instant]         | Driver confirmation                      |
| rejectionReason     | Option[String]          |                                          |
| rejectedBy          | Option[PersonId]        |                                          |
| rejectedAt          | Option[Instant]         |                                          |
| tags                | List[String]            |                                          |
| bookingReference    | Option[String]          | Human-readable per-company reference     |

### ScheduleDay
A driver's work shift for a specific day. `schedule/.../ScheduleDomain.scala`.

| Field     | Type                | Notes          |
|-----------|---------------------|----------------|
| id        | `ScheduleDayId`     |                |
| driverId  | `PersonId`          |                |
| companyId | `CompanyId`         | Company-scoped |
| date      | LocalDate           |                |
| startTime | LocalTime           |                |
| endTime   | LocalTime           |                |
| status    | `ScheduleDayStatus` |                |
| notes     | Option[String]      |                |
| createdAt | Instant             |                |
| updatedAt | Instant             |                |

### Expense
Driver / ride expense line. `ride/.../Expense.scala`.

| Field       | Type              | Notes                             |
|-------------|-------------------|-----------------------------------|
| id          | `ExpenseId`       |                                   |
| rideId      | Option[RideId]    | Optional ride binding             |
| driverId    | `PersonId`        |                                   |
| companyId   | `CompanyId`       |                                   |
| category    | `ExpenseCategory` | Fuel / Parking / Tolls / …        |
| amount      | BigDecimal        |                                   |
| currency    | String            | Default "EUR"                     |
| description | Option[String]    |                                   |
| receiptUrl  | Option[String]    |                                   |
| createdAt   | Instant           |                                   |
| updatedAt   | Instant           |                                   |

### CompanySettings
Per-company operational / billing config. `core/.../CompanySettings.scala`.

| Field                     | Type           | Notes                            |
|---------------------------|----------------|----------------------------------|
| companyId                 | `CompanyId`    |                                  |
| commissionRate            | BigDecimal     | Default 15.00                    |
| workingHoursStart / End   | String         | "06:00" / "22:00"                |
| defaultCurrency           | String         | "EUR"                            |
| cancellationFeeDefault    | BigDecimal     |                                  |
| noShowFee                 | BigDecimal     |                                  |
| autoAssignEnabled         | Boolean        |                                  |
| datevBeraternummer / Mandantennummer / Sachkontenlaenge | Option | DATEV export config |
| airportBufferMinutes      | Option[Int]    | Airport-transfer timing          |
| airportCheckInCloseMinutes | Option[Int]   |                                  |

## Other Domain Entities

Compact registry of the remaining significant entities (see source for fields).

### core
- **Location** — address + optional lat/long value object.
- **Session** — auth session (token, device, activity).
- **BlacklistEntry** — client↔driver blacklist pairing per company.
- **AuditLogEntry** — immutable audit record (actor, action, entity, old/new value).
- **Geofence** / **GeofenceAlert** — circular geo zone and its entry/exit event.
- **RidePool** / **RidePoolMember** — a shared-ride pool and a ride's membership in it.
- **EmergencyReassignment** — emergency driver-reassignment record.
- **NotificationPreference** — per-person notification toggles and quiet hours.
- **GdprConsent** / **GdprRequest** / **GdprDataExport** — GDPR consent, export/deletion request, export payload.

### driver
- **DriverLocation** — a driver's latest GPS position (+ Haversine helper).

### ride
- **RideSpecifics** — sealed ride-type detail (see below).
- **CompanyTariff** — per-company pricing config + fare estimation.
- **DriverEarnings** / **DriverEarningsReport** / **EarningsBucket** — per-period earnings aggregates.
- **FlightInfo** / **FlightStatusRow** — live MUC flight data and its persisted columns on a ride.
- **ClientAddress** — a client's saved address (label, aliases, use count).
- **Airport** / **AirportCheckpointZone** — global airport config and its terminal checkpoint zones.
- **PartnerCompany** / **ExternalDriver** — external hand-off target company and driver.
- **RideShareToken** — opaque public read-only ride-tracking token (guest tracking).
- **RideRating** — client rating/comment for a completed ride.
- **RideTemplate** — recurring-ride template (recurrence pattern, pickup time).
- **ChatMessage** — in-ride chat message.

### schedule
- **DriverScheduleVisibility** — per-driver permission to view others' schedules.
- **DriverUnavailability** — a driver's unavailable window (lunch / vacation / personal).
- **CalendarShareInvite** / **CalendarShareGrant** — invite token and revocable grant to read another person's PII-free calendar.

### notification
- **AppNotification** — in-app notification (title, body, type, read flag).
- **FcmToken** / **PushNotification** — a person's FCM push token and the push payload value object.

### billing
- **Invoice** / **InvoiceItem** — a B2B invoice (period, tax, totals, status) and its line items.
- **CompanyBillingProfile** — issuer (taxi company) legal / bank details for invoice rendering.

## Value Objects / IDs

All IDs are UUID-based wrappers using time-ordered epoch UUIDs (`UuidCreator.getTimeOrderedEpoch()`),
e.g. `PersonId`, `CompanyId`, `ClientCompanyId`, `RideId`, `TariffId`, `ScheduleDayId`, `RidePoolId`,
`ExpenseId`, `ExternalDriverId`, `PartnerCompanyId`.

### Location

| Field     | Type           |
|-----------|----------------|
| address   | String         |
| latitude  | Option[Double] |
| longitude | Option[Double] |

## Enums

Case values are copied verbatim from the domain code. Where the wire form differs from the case
name it is shown as `→ wire`.

### core
- **PersonRole** — `Driver`, `Client`, `Secretary`, `Dispatcher`, `Admin`, `ClientSecretary`, `SuperAdmin`. Wire: SCREAMING_SNAKE via `PersonRole.toWire` (`ClientSecretary → CLIENT_SECRETARY`, `SuperAdmin → SUPER_ADMIN`, others uppercased).
- **UserStatus** — `ACTIVE`, `INACTIVE`, `SUSPENDED`.
- **CompanyStatus** — `Active`, `Suspended`, `Trial`, `Inactive`.
- **SubscriptionPlan** — `Free`, `Starter`, `Professional`, `Enterprise`.
- **AuditAction** — `RideCreated`, `RideAssigned`, `RideReassigned`, `RideCancelled`, `RideStatusChanged`, `RideEdited`, `UserCreated`, `UserUpdated`, `UserDeactivated`, `PaymentRecorded`, `DriverAvailabilityChanged`, `AuthorizationDenied`, `RideHandedOff`.
- **EmergencyReason** — `DriverIllness`, `VehicleBreakdown`, `DriverNoShow`, `Accident`, `PersonalEmergency`, `Other`.
- **ReassignmentStatus** — `PENDING`, `REASSIGNED`, `CANCELLED`.
- **ConsentType** — `DataProcessing`, `Marketing`, `Analytics`, `ThirdPartySharing`.
- **GdprRequestType** — `EXPORT`, `DELETION`.
- **GdprRequestStatus** — `PENDING`, `PROCESSING`, `COMPLETED`, `REJECTED`.
- **GeofenceType** — `Airport`, `ServiceArea`, `ClientPickup`, `CustomZone`.
- **PoolStatus** — `Open`, `Full`, `InProgress`, `Completed`, `Cancelled`.
- **PoolMemberStatus** — `Pending`, `Confirmed`, `PickedUp`, `DroppedOff`, `Cancelled`.

### driver
- **DriverStatus** — `Available`, `Busy`, `Offline`.

### ride
- **RideStatus** — `Requested`, `Assigned`, `Confirmed`, `InProgress`, `Completed`, `Cancelled`, `HandedOff`.
- **PaymentStatus** — `Unpaid`, `Pending`, `Paid`.
- **PaymentMethod** — `Cash`, `Card`, `Invoice`, `Bank`, `Receivable`, `Payment`.
- **VehicleClass** — `Business`, `Van` (→ `business`, `van`; default `Business`).
- **CancellationReason** — `ClientNoShow`, `ClientRequest`, `DriverUnavailable`, `Weather`, `VehicleIssue`, `Other` (→ snake_case).
- **AirportCheckpoint** — `Landed`, `ArrivalsHall`, `TerminalExit` (→ `landed`, `arrivals_hall`, `terminal_exit`).
- **FlightStatus** — `Scheduled`, `Boarding`, `Departed`, `EnRoute`, `Landed`, `Delayed`, `Cancelled`, `Diverted`, `Unknown` (→ snake_case).
- **ExpenseCategory** — `Fuel`, `Parking`, `Tolls`, `Cleaning`, `Maintenance`, `Other`.
- **RecurrencePattern** — `DAILY`, `WEEKLY_MON`…`WEEKLY_SUN`, `WEEKDAYS`, `CUSTOM`.
- **EarningsPeriod** — `Day`, `Week`, `Month`.

### schedule
- **ScheduleDayStatus** — `Scheduled`, `Active`, `Completed`, `Cancelled`.
- **DriverUnavailabilityReason** — `Lunch`, `Vacation`, `Personal`.

### billing
- **InvoiceStatus** — `Draft`, `Sent`, `Paid`, `Cancelled` (→ lowercase).

## RideSpecifics

Sealed trait for ride-type-specific data, stored as JSONB in PostgreSQL.

- **AirportTransfer** — `airportCode`, `flightNumber`, `isArrival`. Live gate/terminal/entry-time are
  looked up on demand from the flight board (not stored on the ride).

## Ride Lifecycle

```
Requested ──→ Assigned ──→ Confirmed ──→ InProgress ──→ Completed
    │             │            │              │
    └─────────────┴────────────┴──────────────┴──→ Cancelled

Assigned/Confirmed ──→ HandedOff   (delegated to an external driver)
```

- `canBeAssigned`: status == Requested
- `canBeStarted`: driver has confirmed and the ride is due
- `canBeCompleted`: status == InProgress

## Key Business Rules

- **Company isolation** — rides, schedules, and assignments are scoped to a company.
- **Assignment rules** — only `Requested` rides can be assigned; the driver must exist and be valid.
- **Driver proximity** — the Haversine formula calculates distance in meters.
- **Schedule uniqueness** — one active schedule day per driver per date within a company.
- **Status transitions** — invalid transitions raise `InvalidStatusTransition` errors.
- **Blacklist** — blacklisted client-driver pairs cannot be assigned.
- **Preferred driver** — VIP clients can have a preferred driver.
