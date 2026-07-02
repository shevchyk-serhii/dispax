# Ride Flows — End-to-End Map for Test Building

> **Purpose.** A single map of every ride flow (create / cancel / modify) from the Flutter UI
> through BLoC and service to the backend endpoint, status machine, side-effects and failure modes.
> Use it as a **test-case catalogue**: each Given/When/Then block is a candidate unit / integration /
> BDD / Flutter test. The "Test coverage" section (§8) tracks which already exist and which are gaps.
>
> **Source of truth is the code**, not this prose. Every claim carries a `file:line` reference.
> Cross-references: domain model — [`docs/domain.md`](domain.md); business rules —
> [`docs/requirements.md`](requirements.md); known bugs — [`docs/audit-tasks.md`](audit-tasks.md).
>
> All paths are relative to the repo root. Backend = `ride/src/main/scala/com/shevchyk/ride/...`,
> Flutter = `web/lib/...`.

---

## 1. Overview

A ride moves through a status machine and is isolated per `CompanyId` (from the JWT claims).

```
Requested ─assign─▶ Assigned ─confirm─▶ Confirmed ─start─▶ InProgress ─complete─▶ Completed
    │                  │ ▲                  │ ▲                 │
    │                  │ └────reject────────┘ │                 │
    │                  └───────reject─────────┘                 │
    ├─hand-off─▶ HandedOff                                       │
    └──────────────────────────cancel───────────────────────────┘
                                  ▼
                              Cancelled (terminal)          Completed (terminal)
```

`RideStatus` enum: `Requested, Assigned, Confirmed, InProgress, Completed, Cancelled, HandedOff`
(`ride/domain/RideDomain.scala:161`). Drivers **confirm** an assignment before they can start it,
and may **reject** it back to the pool; a dispatcher can **hand off** an unassigned ride to an
external driver / partner company.

**Roles** (`core/domain/CoreDomain.scala`): `Driver, Client, Secretary, Dispatcher, Admin,
ClientSecretary, SuperAdmin`. Wire format is **SCREAMING_SNAKE_CASE** via `PersonRole.toWire`
(e.g. `ClientSecretary → CLIENT_SECRETARY`, `SuperAdmin → SUPER_ADMIN`) —
`core/domain/CoreDomain.scala:85-89`.

**Atomicity.** All status transitions go through a compare-and-set:
`RideRepository.updateIfStatus(ride, expectedStatuses)` —
`ride/repository/PostgresRideRepository.scala:313-323`
(`UPDATE rides SET ... WHERE id = ? AND status IN (...)`, returns `false` if 0 rows). Airport
checkpoints use a forward-only CAS `updateCheckpoint` — `:641-663`. **The race loser gets
`InvalidStatusTransition`**, never a silent overwrite, and **side-effects fire only on a successful
CAS**.

**Tenant isolation.** Cross-tenant access is hidden as `RideNotFound` (404), not `Forbidden`, to
avoid leaking the existence of other companies' rides (e.g. `assignDriverServer`
`ride/openapi/RideApi.scala:430-435`).

---

## 2. Status machine — transitions

Status predicates live on the `Ride` domain object (`ride/domain/RideDomain.scala:270-281`):

| Action       | From → To                                                           | Predicate         | Who (HTTP `checkRole`)                 | Endpoint                              |
|--------------|---------------------------------------------------------------------|-------------------|----------------------------------------|---------------------------------------|
| Assign       | `Requested` → `Assigned`                                            | `canBeAssigned`   | DISPATCHER                             | `PUT /api/rides/{id}/assign-driver`   |
| Confirm      | `Assigned` → `Confirmed`                                            | `canBeConfirmed`  | DRIVER (own)                           | `PUT /api/rides/{id}/confirm`         |
| Reject       | `{Assigned,Confirmed}` → `Requested`                                | `canBeRejected`   | DRIVER (own)                           | `PUT /api/rides/{id}/reject`          |
| Reassign     | `{Assigned,Confirmed}` → `Assigned` (new driver)                    | `canBeReassigned` | DISPATCHER                             | `PUT /api/rides/{id}/reassign-driver` |
| Start        | `Confirmed` → `InProgress`                                          | `canBeStarted`    | DRIVER (own), DISPATCHER               | `PUT /api/rides/{id}/status`          |
| Complete     | `InProgress` → `Completed`                                          | `canBeCompleted`  | DRIVER (own), DISPATCHER               | `PUT /api/rides/{id}/status`          |
| Hand-off     | `Requested` → `HandedOff`                                           | `canBeHandedOff`  | DISPATCHER, ADMIN                      | `PUT /api/rides/{id}/hand-off`        |
| Cancel       | `{Requested,Assigned,Confirmed,InProgress,HandedOff}` → `Cancelled` | `canBeCancelled`  | DRIVER (own), DISPATCHER, CLIENT (own) | `PUT /api/rides/{id}/cancel`          |
| Edit details | only `Requested`, `Assigned` or `Confirmed`                         | `canBeEdited`     | DRIVER, DISPATCHER, SECRETARY, CLIENT  | `PUT /api/rides/{id}`                 |

> `canBeCancelled = status != Completed && status != Cancelled`.
> `canBeStarted`/`canBeReassigned`/`canBeConfirmed`/`canBeRejected` also require `driverId.isDefined`.
> **Reject** clears the driver and returns the ride to `Requested` (back to the pool), recording
> `rejectionReason`/`rejectedBy`/`rejectedAt`. After a **reassign** the new driver must confirm again.

---

## 3. CREATE

**Backend:** `POST /api/rides` → `createRideServer` (`ride/openapi/RideApi.scala:254-291`) →
`RideService.createRide` (`ride/application/service/RideService.scala:114-184`).
**Estimate (optional pre-step):** `POST /api/rides/estimate` →
`RideEstimateService` (`ride/application/service/RideEstimateService.scala:77-105`).

### Role matrix (creation)

| Role             | Can create? | clientId source                                                   | May assign driver at create? |
|------------------|-------------|-------------------------------------------------------------------|------------------------------|
| CLIENT           | yes         | forced to JWT `userId` (`:263-264`)                               | no (own ride only)           |
| DRIVER           | yes         | only own (`clientId == userId`, else passes through) (`:265-266`) | self-booking only            |
| SECRETARY        | yes         | any (subject to tenant check)                                     | yes (`driverId` in request)  |
| DISPATCHER       | yes         | any (subject to tenant check)                                     | yes                          |
| CLIENT_SECRETARY | yes         | any (subject to tenant check)                                     | yes                          |

`checkRole`: `DISPATCHER, SECRETARY, CLIENT, DRIVER, CLIENT_SECRETARY` (`:256`). ADMIN / SUPER_ADMIN
are **not** in this list — they cannot create via this endpoint.

### DTO & validation

`CreateRideApiRequest` — `ride/infrastructure/http/dto/RideApiModels.scala:84-104`.
Accumulating validator (`Validator.accumulate`) — `ride/validation/RideValidators.scala:28-93`:
- pickup/dropoff address non-empty after trim;
- latitude ∈ [-90, 90], longitude ∈ [-180, 180], not NaN/∞ (missing coords allowed — geocoded later);
- `pickupDateTime` parseable ISO-8601 and **not in the past** (5-min skew tolerance,
  `RidePolicy.ClockSkewToleranceSeconds`);
- `clientId` valid UUID;
- if `isAirportTransfer` → `flightNumber` required;
- if `price` present → `price > 0`.

### Service preconditions & side-effects

In `createRide` (`RideService.scala:114-184`):
1. scheduled time not in the past (`:117-121`);
2. pickup address ≠ dropoff address (`:123-127`);
3. **tenant isolation** — the client must belong to the creator's company
   (`client.companyId.contains(request.companyId)`, `:128-137`) → else
   `BusinessRuleViolation("company_isolation")`;
4. geocoding enriches both locations, falls back to input on failure (`:138-143`);
5. entry status is `Requested` (via `RideMapper.fromRequest`).

**Side-effects** (all `.ignore`d on failure): WS `RideCreated` (`:148-156`), email/SMS confirmation
(`:157-170`), audit `RideCreated` with `actorId = clientId` (`:171-183`). After the service returns,
the handler optionally **assigns a driver** when `driverId` is in the request (`:272-278`), then
records pickup/dropoff addresses for autocomplete (`recordUsage`, `:280-289`).

### Variants
- **Immediate vs scheduled** — same endpoint; `scheduledTime` differs.
- **Airport transfer** — `RideSpecifics.AirportTransfer(airportCode, flightNumber, isArrival)`;
  `airportCode` heuristically derived from the address.
- **Estimate** — Haversine distance (not HERE — avoids a `ride → driver` module dependency) + company
  tariff + night surcharge (22:00–06:00 Europe/Berlin); needs both endpoints' coordinates else
  `MissingCoordinates` (`RideEstimateService.scala:92`).

### Flutter
- Dispatcher/Secretary: `screens/create_ride_screen.dart` + `blocs/create_ride_form/` BLoC.
- Client: `dashboard/client/client_book_screen.dart` (with estimate step + vehicle-class pick).
- Submit chain: `FormSubmitted` → `CreateRideFormHelper.handleFormSubmission()` →
  `RideCreateRequested` (RideBloc) → `RideService.createRide()` → `POST /rides`.
- Estimate chain: address change → `RideEstimateService.estimate()` → `POST /rides/estimate` →
  `EstimateReceived`.

### Test cases (Given/When/Then)

```gherkin
Scenario: Dispatcher creates a ride for a client of their company
  Given a dispatcher of company A and a client C of company A
  When the dispatcher POSTs /api/rides with clientId=C and valid pickup/dropoff/time
  Then a ride is created with status Requested, companyId=A
  And a RideCreated WS event and a RideCreated audit entry are emitted

Scenario: Client self-booking forces clientId to the JWT user
  Given a client logged in as user U
  When the client POSTs /api/rides with clientId=<someone-else>
  Then the created ride's clientId is U (the request value is ignored)

Scenario: Driver may only self-book
  Given a driver D
  When D POSTs /api/rides with clientId != D
  Then the clientId is not forced and the company-isolation check applies as for any other client

Scenario: Tenant isolation blocks cross-company client
  Given a secretary of company A
  When they POST /api/rides with a clientId belonging to company B
  Then it fails with BusinessRuleViolation("company_isolation") (400)

Scenario: Same pickup and dropoff address is rejected
  When POST /api/rides has from.address == to.address
  Then it fails with ValidationError (400)

Scenario: Pickup in the past is rejected
  When pickupDateTime is more than 5 minutes in the past
  Then validation fails (400)

Scenario: Airport transfer without a flight number is rejected
  When isAirportTransfer=true and flightNumber is absent
  Then validation fails (400)

Scenario: Non-positive price is rejected
  When price <= 0 is supplied
  Then validation fails (400)

Scenario: Create with immediate driver assignment
  Given a dispatcher and an available driver D of the same company
  When POST /api/rides includes driverId=D
  Then the ride is created (Requested) then assigned to D (Assigned) in one request

Scenario: Estimate without coordinates fails cleanly
  When POST /api/rides/estimate has from/to without lat/lng
  Then it fails with MissingCoordinates
```

---

## 4. CANCEL

**Backend:** `PUT /api/rides/{rideId}/cancel` → `cancelRideServer`
(`ride/openapi/RideApi.scala:559-575`) → `RideService.cancelRideWithReason`
(`RideService.scala:273-343`). There is also a no-reason `cancelRide` (`:249-271`) used internally.

### Role matrix (cancel)

HTTP `checkRole`: **DRIVER, DISPATCHER, CLIENT** only (`RideApi.scala:562`). The service-level
`validateCancelPermission` (`RideService.scala:808-816`) additionally allows Secretary/Admin/
ClientSecretary/SuperAdmin **if** they reach the service, but **the HTTP layer rejects those roles
first** — so over the API only the three below can cancel:

| Role       | Can cancel            | Ownership rule                               |
|------------|-----------------------|----------------------------------------------|
| CLIENT     | own rides only        | `ride.clientId == userId` (`:813-814`)       |
| DRIVER     | assigned-to-them only | `ride.driverId contains userId` (`:815-816`) |
| DISPATCHER | any ride              | no ownership check (`:810-812`)              |

### Preconditions
- status must be cancellable: must **not** be `Cancelled` → `InvalidStatusTransition` (`:281-285`);
  must **not** be `Completed` → `UnauthorizedAccess` (`:286`);
- cancellation `fee >= 0` — validator `RideValidators.scala:150-166` **and** service guard
  (`:291-295`) so direct callers can't bypass it.

### Atomicity & side-effects
CAS on `Set(Requested, Assigned, Confirmed, InProgress, HandedOff)` (`:613-626` — `HandedOff` is
included so a handed-off ride can still be cancelled). On success only: WS
`RideStatusChanged(newStatus="Cancelled")` and audit `RideCancelled` with `reason`. Mutated fields:
`status, cancellationReason, cancellationFee, cancelledBy` (`:599-607`).

### Flutter
`widgets/common/cancel_ride_dialog.dart` (reason dropdown; fee field shown only when `isDispatcher`).
Opened from `screens/ride_details_screen.dart` (`_cancelRide`). **Calls `RideService.cancelRide()`
directly — bypasses RideBloc**, then patches local state to `cancelled`.

### Test cases (Given/When/Then)

```gherkin
Scenario Outline: Cancel from each valid source status
  Given a ride in status <status> (Requested | Assigned | InProgress)
  When an authorised caller PUTs /api/rides/{id}/cancel with a reason
  Then the ride becomes Cancelled
  And exactly one RideStatusChanged WS event and one RideCancelled audit entry are emitted

Scenario: Cancelling an already-cancelled ride
  Given a Cancelled ride
  When cancel is requested again
  Then it fails with InvalidStatusTransition (not idempotent)

Scenario: Cancelling a Completed ride
  Given a Completed ride
  When cancel is requested
  Then it fails with UnauthorizedAccess (403)

Scenario: Client cannot cancel another client's ride
  Given a ride owned by client X
  When client Y cancels it
  Then it fails with UnauthorizedAccess

Scenario: Driver cannot cancel a ride not assigned to them
  Given a ride assigned to driver A
  When driver B cancels it
  Then it fails with UnauthorizedAccess

Scenario: Negative cancellation fee is rejected
  When cancel is requested with fee < 0
  Then it fails with ValidationError and the status is unchanged

Scenario: Race — cancel loses to a concurrent start/complete/reassign
  Given an Assigned ride
  When a cancel and a start are submitted concurrently
  Then exactly one wins; the loser gets InvalidStatusTransition
  And no side-effects fire for the losing cancel
```

---

## 5. MODIFY

### 5.1 Assign driver
`PUT /api/rides/{rideId}/assign-driver` → `assignDriverServer` (`RideApi.scala:420-440`) →
`RideService.assignDriver` (`:505-592`). Role: **DISPATCHER**.
- Preconditions: `canBeAssigned` (status `Requested`); driver exists & `canDrive`; **same company**;
  not blacklisted for the client; no schedule conflict (`checkScheduleConflict`,
  `:840-876` — 60-min default duration + 30-min buffer).
- HTTP-level tenant check hides cross-tenant rides as `RideNotFound` (`:430-435`).
- CAS on `Set(Requested)`; side-effects on success: WS `RideAssigned`, email/SMS driver assignment,
  audit `RideAssigned`. Sets `driverId`, `isVipRide`, `preferredDriverUsed`.
- Flutter: `dashboard/dispatcher/widgets/pending_rides_panel.dart` → `RideAssignRequested` →
  `RideService.assignDriver()`.

```gherkin
Scenario: Assign succeeds only from Requested
  Given a Requested ride and an available same-company driver
  When the dispatcher assigns the driver
  Then the ride becomes Assigned and RideAssigned WS + audit fire

Scenario: Assign a driver of another company
  Then it fails with BusinessRuleViolation("company_isolation")

Scenario: Assign a blacklisted driver
  Then it fails with BusinessRuleViolation("blacklist")

Scenario: Assign with a schedule conflict
  Given the driver already has an overlapping Assigned/InProgress ride
  Then it fails with ScheduleConflict (409)

Scenario: Assign to a non-Requested ride / cross-tenant ride
  Then InvalidStatusTransition / RideNotFound (404) respectively
```

### 5.2 Reassign driver
`PUT /api/rides/{rideId}/reassign-driver` → `reassignDriverServer` (`RideApi.scala:442-461`) →
`RideService.reassignDriver` (`:960-...`). Role: **DISPATCHER**.
- Precondition `canBeReassigned` (status `Assigned` **or** `Confirmed` + has driver); same
  driver/company/blacklist checks; schedule conflict skipped when `overrideScheduleConflict=true`;
  self excluded from the conflict scan.
- CAS on `Set(Assigned, Confirmed)` → back to `Assigned` (the new driver must confirm again); on
  success: WS `RideAssigned`, audit `RideReassigned` (old + new driver).
- Flutter: `RideReassignRequested`; a backend 409 surfaces `RideStateStatus.reassignConflict` →
  override dialog → retry with the flag set.

```gherkin
Scenario: Reassign from Assigned with override clears a conflict
  Given an Assigned ride with a scheduling conflict against the new driver
  When reassign is requested with overrideScheduleConflict=true
  Then it succeeds and audit RideReassigned records old+new driver

Scenario: Reassign a Requested (unassigned) ride
  Then it fails (canBeReassigned is false)
```

### 5.3 Start & Complete (status update)
`PUT /api/rides/{rideId}/status` → `updateRideStatusServer` (`RideApi.scala:400-418`) →
`RideService.updateRideStatus` (`:352-451`); also direct `startRide` (`:191-227`) /
`completeRide` (`:229-247`). Roles: **DRIVER (own), DISPATCHER**.
- Start: precondition `canBeStarted` (status `Confirmed`); driver must be the assigned one; CAS on
  `Set(Confirmed)`; sets `startTime`. (A ride must be **confirmed** before it can start — see §5.9.)
- Complete: precondition `canBeCompleted`; CAS on `Set(InProgress)`; sets `endTime`.
- Side-effects on success: WS `RideStatusChanged`, audit `RideStatusChanged`.
- Flutter: driver quick actions (`modules/driver_management/widgets/ride_quick_actions.dart`) →
  `RideStatusUpdateRequested` → `RideService.updateRideStatus()`.

```gherkin
Scenario: Driver starts their own Assigned ride
  Then status becomes InProgress, startTime is set, RideStatusChanged fires

Scenario: A non-assigned driver tries to start the ride
  Then it fails with UnauthorizedAccess

Scenario: Complete a ride that is not InProgress
  Then InvalidStatusTransition

Scenario: Race — start loses to a concurrent cancel
  Then exactly one applies; the loser gets InvalidStatusTransition
```

### 5.4 Edit ride details
`PUT /api/rides/{rideId}` → `updateRideServer` (`RideApi.scala:463-480`) →
`RideService.updateRideDetails` (`:453-503`). Roles: **DRIVER, DISPATCHER, SECRETARY**.
- Precondition `canBeEdited` (status `Requested` or `Assigned`); creator or Dispatcher may edit;
  tenant check via passed `companyId`.
- ⚠️ Uses a **plain `update`, not a CAS** — two concurrent edits in an editable status can overwrite
  each other (no field-level versioning). Acceptable because edits are blocked once `InProgress`.
- Side-effect: clears reminders when `pickupDateTime` changes (`clearReminders`). Mutable fields:
  pickup/dropoff (re-geocoded), `pickupDateTime`, `notes`, `specifics`, `specialRequirements`.

```gherkin
Scenario: Edit a Requested ride's pickup time
  Then the ride is updated and its reminders are cleared

Scenario: Non-creator non-dispatcher edits a ride
  Then UnauthorizedAccess

Scenario: Edit an InProgress ride
  Then InvalidStatusTransition (not editable)
```

### 5.5 Mark payment
`PUT /api/rides/{rideId}/payment` → `markPaymentServer` (`RideApi.scala:541-557`) →
`RideService.markPayment` (`:699-743`). Roles: **DISPATCHER, ADMIN**.
- Marking `Paid` requires status `Completed`, enforced twice (Scala guard `:707-711` + CAS on
  `Set(Completed)` `:732-741`). Other payment statuses take a plain update. Idempotent `paidAt`
  (`:712-713`).
- HTTP-level tenant check (`:549-552`).
- ⚠️ **Known bug (documented in code `:729-731`):** the CAS guards the ride *status* only — two
  concurrent `markPayment(Paid)` on the same Completed ride can lost-update each other's payment
  fields. See §7.
- Flutter: payment is **read-only** in `ride_details_screen.dart`; no client-side mark action found.

```gherkin
Scenario: Mark a Completed ride as Paid
  Then paymentStatus=Paid, paidAt set once (idempotent on repeat)

Scenario: Mark a non-Completed ride as Paid
  Then BusinessRuleViolation("payment_status")

Scenario: Cross-tenant markPayment
  Then UnauthorizedAccess

Scenario [REGRESSION/gap]: Concurrent markPayment(Paid) on the same ride
  Then payment fields must not lost-update (currently can — see §7)
```

### 5.6 Rate ride
`POST /api/rides/{rideId}/rate` → handler at `RideApi.scala:668-710`. Role: **CLIENT (own)**.
- Preconditions: ride `Completed`; client owns it; not already rated; rating ∈ [1, 5]; tenant check.
  Writes a separate `RideRating` row (does not mutate the ride).
- Flutter: `widgets/common/rate_ride_dialog.dart` → **direct `apiClient.post('/rides/{id}/rate')`**
  (no BLoC).

```gherkin
Scenario: Client rates their own Completed ride 1..5
  Then a RideRating row is created

Scenario: Rate a non-Completed ride / rate twice / rating out of [1,5] / rate someone else's ride
  Then BusinessRuleViolation / duplicate error / ValidationError / UnauthorizedAccess respectively
```

### 5.7 Airport checkpoint
`POST /api/rides/{rideId}/airport-checkpoint` → `RideApi.scala:731-748` →
`AirportCheckpointService` (`:78-125`). Role: **CLIENT**.
- Forward-only: `Landed(0) → ArrivalsHall(1) → TerminalExit(2)`, enforced by `updateCheckpoint` CAS
  (`PostgresRideRepository.scala:641-663`). Only on an in-progress arrival airport transfer.
- WS `AirportCheckpointReached` on success (when the ride has a driver). Auto-`Landed` can be
  triggered by a client-location geofence hit (§5.8).

```gherkin
Scenario: Client advances Landed -> ArrivalsHall -> TerminalExit
  Then each forward step succeeds; a backward/same step fails (InvalidOperation)

Scenario: Race — two concurrent checkpoint advances
  Then only the higher one applies (forward-only CAS)
```

### 5.8 Secondary modifications
- **Client location** — `POST /api/rides/{rideId}/client-location` (CLIENT, own ride; tenant +
  ownership checks); WS `LocationUpdated`; may auto-trigger `Landed` checkpoint.
- **Driver location / availability** — `PUT /api/drivers/{driverId}/location` &
  `/availability` (driver own, or DISPATCHER); coordinate-range validation; WS `LocationUpdated`;
  geofence checks forked async.
- **Expenses** — `POST /api/expenses` (DRIVER, DISPATCHER, ADMIN; amount > 0),
  `DELETE /api/expenses/{id}` (owner driver / DISPATCHER / ADMIN; tenant + ownership).
- **Chat** — `POST /api/rides/{rideId}/chat` (CLIENT, DRIVER; tenant check).

### 5.9 Confirm ride (driver acceptance)
`PUT /api/rides/{rideId}/confirm` → `confirmRideServer` (`RideApi.scala:853-867`) →
`RideService.confirmRide` (`:353-417`). Role: **DRIVER** (must be the assigned driver).
- Precondition `canBeConfirmed` (status `Assigned` + has driver); CAS on `Set(Assigned)`; sets
  `confirmedAt`. A second confirm yields `RideAlreadyConfirmed` (`RideDomain.scala:354`).
- Side-effect on success: WS `RideConfirmed`. **No push is sent** — dispatchers see it via WebSocket,
  and the client is not notified while the ride is still pending departure
  (`PushNotificationListener.scala:333-336`).
- Flutter: driver `RideConfirmRequested` (`blocs/ride/ride_event.dart`).

```gherkin
Scenario: Assigned driver confirms their ride
  Then status becomes Confirmed, confirmedAt is set, RideConfirmed WS fires (no push)

Scenario: A non-assigned driver confirms
  Then UnauthorizedAccess

Scenario: Confirm a non-Assigned ride / confirm twice
  Then InvalidStatusTransition / RideAlreadyConfirmed
```

### 5.10 Reject ride (driver decline)
`PUT /api/rides/{rideId}/reject` → `rejectRideServer` (`RideApi.scala:869-...`) →
`RideService.rejectRide` (`:419-...`). Role: **DRIVER** (must be the assigned driver).
- Precondition `canBeRejected` (status `Assigned` or `Confirmed` + has driver); reason required;
  CAS on `Set(Assigned, Confirmed)`. On success the ride returns to **Requested**, `driverId` is
  cleared and `rejectionReason`/`rejectedBy`/`rejectedAt` are recorded — back to the pool.
- Side-effect on success: WS `RideRejected` → push to **all dispatchers** of the company so they can
  reassign in time (`PushNotificationListener.scala:338-353`).
- Flutter: `RideRejectRequested(reason)` via the reject-reason preset dialog (4 localized presets +
  free-text "Other"; a stable English string is sent to the backend).

```gherkin
Scenario: Driver rejects an Assigned ride with a reason
  Then status returns to Requested, driverId is cleared, rejectionReason recorded
  And a RideRejected push goes to all dispatchers

Scenario: Reject without a reason / reject a ride not assigned to the caller
  Then ValidationError / UnauthorizedAccess
```

### 5.11 Hand-off to external driver
`PUT /api/rides/{rideId}/hand-off` → `handOffRideServer` (`RideApi.scala:667-...`) →
`RideService.handOffToExternal` (`:1381-...`). Roles: **DISPATCHER, ADMIN**.
- Precondition `canBeHandedOff` (status `Requested`); the external driver and partner company must
  exist; CAS on `Set(Requested)` → **HandedOff**, recording the external driver / partner company.
- A handed-off ride can still be cancelled afterwards (`HandedOff` is in the cancellable set).

```gherkin
Scenario: Dispatcher hands off a Requested ride to a partner
  Then status becomes HandedOff with the external driver / partner recorded

Scenario: Hand off a non-Requested ride
  Then InvalidStatusTransition (canBeHandedOff is false)
```

---

## 6. Notifications — event → recipient → channel

Three channels carry ride events:
- **WebSocket** — real-time push to dashboards, filtered by `companyId` from the JWT
  (`api/.../routes/WebSocketRoutes.scala`; connect via a short-lived ticket from `POST /api/ws/ticket`,
  then `GET /api/ws`). Events are the `WebSocketEvent` subtypes in `core/.../domain/WebSocketEvent.scala`,
  published through `EventHub`.
- **FCM push** — mobile push via `FcmService.sendToUser` (Firebase), one message per registered device.
- **In-app inbox** — persisted `AppNotification` rows (`app_notifications`) for history.

`PushNotificationListener.handleEvent()` (`notification/.../application/PushNotificationListener.scala`)
fans a `WebSocketEvent` out to FCM + inbox via `notifyUser`.

| Event                            | Recipients                                      | Channel          | Notes                                                                                 |
|----------------------------------|-------------------------------------------------|------------------|---------------------------------------------------------------------------------------|
| `RideCreated`                    | Client; dispatchers                             | FCM + inbox / WS | Client gets a booking confirmation; dispatchers see it via WS in Pending (`:253-261`) |
| `RideAssigned`                   | Driver + Client                                 | FCM + inbox      | "New ride assigned" / "Driver assigned" (`:101-115`)                                  |
| `RideConfirmed`                  | Dispatchers                                     | **WS only**      | No push — log only (`:333-336`)                                                       |
| `RideRejected`                   | All dispatchers                                 | FCM + inbox      | With the rejection reason (`:338-353`)                                                |
| `RideStatusChanged` → InProgress | Driver + Client                                 | FCM + inbox      | "Ride started" (`:128-140`)                                                           |
| `RideStatusChanged` → Completed  | Driver + Client + all dispatchers               | FCM + inbox      | Dispatchers de-duped vs driver/client (`:141-227`)                                    |
| `RideStatusChanged` → Cancelled  | Driver (if assigned) + Client + all dispatchers | FCM + inbox      | Dispatcher body carries the cancel reason (`:154-216`)                                |
| `RideDetailsUpdated`             | Assigned driver + all dispatchers               | FCM + inbox      | (`:229-251`)                                                                          |
| `LocationUpdated`                | —                                               | WS only          | Live driver/client tracking (`:263`)                                                  |
| `ChatMessageSent`                | —                                               | WS only          | (`:267`)                                                                              |
| `DriverApproaching`              | Client                                          | FCM + inbox      | threshold 2km / 500m / 100m (`:293-306`)                                              |
| `EtaAtRisk`                      | All dispatchers                                 | FCM + inbox      | Late-pickup warning (`:308-...`)                                                      |
| `GeofenceTriggered`              | All dispatchers                                 | FCM + inbox      | entry / exit (`:271-291`)                                                             |
| `AirportCheckpointReached`       | Driver                                          | FCM + inbox      | Once per checkpoint, deduped (`:355-...`)                                             |

Push `data` map: `type`, `rideId`, `driverId`/`clientId`, plus event-specific fields (`status`,
`reason`, `etaMinutes`/`minutesUntilPickup`/`slackMinutes`, `distanceMeters`/`threshold`,
`checkpointType`/`checkpointName`, `geofenceId`/`geofenceName`/`alertType`).

### 6.1 Background notification jobs

| Job                                                                                 | Schedule                       | What it sends                                                                                                                                                                                  | Dedup                                                  |
|-------------------------------------------------------------------------------------|--------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------|
| `PredictiveEtaMonitor` (`api/.../app/PredictiveEtaMonitor.scala`)                   | every minute                   | For assigned rides with pickup in `[now, now+45min]`, computes ETA via `EtaService` (HERE Routing API; Haversine ≈ 50 km/h fallback). If `slack < 5min`, publishes `EtaAtRisk` to dispatchers. | `EtaAlertRepository` per (ride, driver)                |
| `ConfirmationReminderScheduler` (`api/.../app/ConfirmationReminderScheduler.scala`) | 07:00 Europe/Berlin + catch-up | "Confirm your ride" push to drivers with `Assigned` rides.                                                                                                                                     | `SentConfirmationRequestRepository` per (ride, driver) |
| `ReminderScheduler` (`api/.../app/ReminderScheduler.scala`)                         | every minute                   | Using the driver's `reminderMinutes`, "Ride in N min" when pickup enters the window.                                                                                                           | `SentReminderRepository` per (ride, driver)            |

### 6.2 Airport checkpoint notification chain

For arrival airport transfers (`isArrival = true`), the checkpoint advances forward-only
`Landed → ArrivalsHall → TerminalExit` (§5.7). `Landed` can fire automatically when the client's
live location enters the airport geofence; the later two are marked by the client. Each advance
publishes `AirportCheckpointReached` → a push to the **driver** ("Client at &lt;checkpoint&gt;"),
deduped per (ride, driver, checkpoint) via `CheckpointNotificationRepository`
(`PushNotificationListener.scala:355-...`).

---

## 7. Known bugs / gaps (negative-test seeds)

Cross-checked against [`docs/audit-tasks.md`](audit-tasks.md). Each is a regression-test candidate.

| #   | Gap                                                                                                                                                       | Where                                                    | Test to add                                                               |
|-----|-----------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------|---------------------------------------------------------------------------|
| 1   | **Cancel endpoint has no HTTP-level `companyId` check** (unlike assign/reassign/markPayment/getRide which all compare `existing.companyId != companyId`). | `RideApi.scala:559-575`                                  | A dispatcher of company A must not be able to cancel a ride of company B. |
| 2   | `validateCancelPermission` has no `case _` → **MatchError** if a new `PersonRole` is added.                                                               | `RideService.scala:808-816`                              | Adding a role must default to deny, not crash.                            |
| 3   | **markPayment field-level lost-update** — CAS guards ride status only, not the payment fields.                                                            | `RideService.scala:729-731`                              | Two concurrent `markPayment(Paid)` must not clobber each other.           |
| 4   | **ETA reminders not cleared on cancel** (only on edit-details).                                                                                           | `cancelRideWithReason` vs `updateRideDetails` `:453-503` | A reminder must not fire for a cancelled ride.                            |
| 5   | `cancellationFee` is stored but **never auto-charged**; no waiting fee logic.                                                                             | `RideDomain.scala:202`, billing                          | Document expected billing behaviour before testing.                       |

---

## 8. Test coverage map (skeleton)

Existing service-level tests: `ride/src/test/scala/com/shevchyk/ride/application/RideServiceSpec.scala`
(cancel + concurrency around lines 562–889). BDD scenarios: `api/src/test/scala/com/shevchyk/app/`.
Flutter: `bloc_test` + `mocktail`.

| Flow / case                                                   | Backend unit                  | Integration / BDD | Flutter | Notes                                           |
|---------------------------------------------------------------|-------------------------------|-------------------|---------|-------------------------------------------------|
| Create — happy path per role                                  | partial                       | ?                 | ?       | verify each of the 5 roles                      |
| Create — tenant isolation (sec A → client B)                  | ✅ (createRide)               | ?                 | n/a     | see memory `createride-client-tenant-isolation` |
| Create — from==to / past pickup / airport-no-flight / price≤0 | ?                             | n/a               | ?       | validator-level                                 |
| Estimate — MissingCoordinates                                 | ?                             | n/a               | ?       |                                                 |
| Cancel — each valid source status                             | ✅ `RideServiceSpec` ~683-889 | ?                 | ?       |                                                 |
| Cancel — already cancelled / completed                        | ✅                            | ?                 | n/a     |                                                 |
| Cancel — ownership (client/driver)                            | ✅                            | ?                 | n/a     |                                                 |
| Cancel — negative fee                                         | ✅                            | n/a               | ?       |                                                 |
| Cancel — race vs start/complete                               | ✅ ~562-680, 816-868          | n/a               | n/a     | CAS tests                                       |
| **Cancel — HTTP tenant check (gap #1)**                       | ❌                            | ❌                | n/a     | **TODO regression**                             |
| **validateCancelPermission default-deny (gap #2)**            | ❌                            | n/a               | n/a     | **TODO**                                        |
| Assign — happy / conflict / blacklist / cross-tenant          | partial                       | ?                 | ?       |                                                 |
| Reassign — override conflict                                  | ?                             | ?                 | ?       |                                                 |
| Confirm — happy / non-assigned driver / double-confirm        | ?                             | ?                 | ?       | RideConfirmed WS, no push                       |
| Reject — back-to-pool + dispatcher push / no reason           | ?                             | ?                 | ?       | clears driver, status → Requested               |
| Hand-off — Requested → HandedOff / non-Requested              | ?                             | ?                 | ?       |                                                 |
| Start / Complete — happy + race                               | ✅ (CAS)                      | ?                 | ?       | start requires Confirmed                        |
| Edit details — editable statuses + reminder clear             | ?                             | ?                 | n/a     | no CAS — concurrent-edit case                   |
| Notifications — recipient/channel per event (§6)              | ?                             | ?                 | n/a     | listener fan-out + dedup                        |
| Mark payment — Paid requires Completed                        | ?                             | ?                 | n/a     |                                                 |
| **Mark payment — concurrent lost-update (gap #3)**            | ❌                            | ❌                | n/a     | **TODO**                                        |
| Rate — completed / duplicate / out-of-range / ownership       | ?                             | ?                 | ?       |                                                 |
| Airport checkpoint — forward-only + race                      | ?                             | ?                 | ?       |                                                 |

Legend: ✅ exists · partial · ? unverified · ❌ missing.

> When filling this in, follow the project rule (`CLAUDE.md`): a bug fix or functionality change is
> not done without a covering test — a **unit test first** (in-memory double), plus integration/BDD
> if it crosses a repository or HTTP boundary.
