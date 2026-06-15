# Feature Plan — Predictive ETA Monitoring

> Technical implementation plan for the Tier‑1 "Punctuality Guarantee" feature
> (see `market-analysis.md`). Backend (Scala 3 / ZIO) plan.
> Last reviewed: June 2026.

## Context

Dispax positioning is *"the client does not wait"* — punctuality over driver
utilization (`requirements.md`). Today the system can compute a driver's ETA to a
pickup **on demand** (the `GET /api/rides/{rideId}/driver-location` proximity
endpoint), but nothing **proactively** watches assigned rides and warns the
dispatcher when a driver is about to be late. This feature adds a background
monitor that continuously evaluates whether each assigned driver will make the
pickup on time and alerts the dispatcher *before* the client notices.

**MVP scope (decided):** alert the dispatcher only. Reassignment stays manual.
Auto-suggest / auto-reassign are explicitly out of scope (see *Future work*).

> **Status: implemented on `main` (backend).** All steps below are done and
> tested. One scope note: `EtaAlertRepository.clear(rideId)` exists but is **not**
> yet called on pickup-time change (that would require crossing the
> `ride → notification` module boundary, which is reversed). In the MVP a changed
> pickup time can therefore suppress a fresh alert until the ride completes —
> acceptable for v1; wire `clear` from the `api` layer if it proves limiting.

## What already exists (reuse, don't rebuild)

| Building block | Location | Role in this feature |
|---|---|---|
| ETA via HERE Routing API | `driver/.../application/HereRoutingService.scala` — `getEtaMinutes(oLat,oLng,dLat,dLng): Task[Option[Int]]` | Primary ETA source |
| Haversine ETA fallback (50 km/h) | `DriverRoutes.scala` `estimateEtaMinutes(...)` | Fallback when HERE key/route absent |
| On-demand ETA assembly (driver loc → client/pickup coords → HERE → fallback) | `DriverRoutes.scala` lines ~300–314 | **Extract into a shared service** (see step 1) |
| Driver live location | `DriverLocationService.getLocation(driverId): Task[Option[DriverLocation]]` | Origin for ETA |
| Real-time client location | `ClientLocationRepository.getLocation(rideId)` | Preferred destination if present |
| Lazy geocoding of pickup | `GeocodingService.enrichLocation(location)` | Fill missing pickup coords |
| Assigned rides in a time window | `RideRepository.findAssignedRidesInWindow(from, to): Task[List[Ride]]` | Select rides to monitor |
| Background job pattern | `app/ReminderScheduler.scala` — `tick.repeat(Schedule.fixed(1.minute)).forkDaemon` | Template for the monitor |
| Dedup of repeated sends | `SentReminderRepository` (`isAlreadySent` / `markSent`) | Template for alert dedup |
| Event bus → WebSocket + push | `EventHub.publish(event)`; `PushNotificationListener` maps events → FCM + `AppNotification` | Deliver the alert |
| WebSocket events | `core/.../domain/WebSocketEvent.scala` | Add a new `EtaAtRisk` event |
| Daemon startup | `Application.scala` `run` (`PushNotificationListener.start *> ReminderScheduler.start *> ...`) | Wire in the new monitor |

Note: ETA is implemented on **HERE**, not Google (CLAUDE.md names Google as a
requirement, but the code uses HERE — reuse `HereRoutingService`).

## Design

A background daemon (`PredictiveEtaMonitor`) ticks on a fixed schedule. Each tick:

1. Pull assigned rides whose pickup is within a look‑ahead window
   (`findAssignedRidesInWindow(now, now + lookAhead)`).
2. For each ride with a driver: compute current ETA via the shared `EtaService`.
3. Compute the **slack**: `minutesUntilPickup − etaMinutes`. If
   `slack < riskThreshold` (e.g. negative or under a small buffer), the ride is
   *at risk*.
4. Dedup: only alert once per ride per risk‑escalation (via an
   `EtaAlertRepository`, mirroring `SentReminderRepository`). Re‑alert only if the
   situation materially worsens (optional: track last alerted severity).
5. Publish `WebSocketEvent.EtaAtRisk` → `EventHub`. The existing
   `PushNotificationListener` is extended to map this event to a dispatcher push +
   `AppNotification` (type `"eta_at_risk"`).

Tenant isolation: every alert carries `companyId` (already on `Ride`); WebSocket
clients already filter by company, and the dispatcher push must target that
company's dispatchers only.

## Implementation steps

### 1. Extract a reusable `EtaService` (refactor, no behavior change)
**New:** `driver/src/main/scala/com/shevchyk/driver/application/EtaService.scala`

Move the ETA-assembly logic currently inline in `DriverRoutes.scala` into a
service so both the proximity endpoint and the monitor share one implementation:

```scala
trait EtaService:
  /** ETA in minutes from driver's live location to the ride's destination
   *  (client live location if present, else geocoded pickup). None if no driver
   *  location or no usable destination coords. */
  def etaForRide(ride: Ride): Task[Option[Int]]
```

Implementation reuses `DriverLocationService.getLocation`,
`ClientLocationRepository.getLocation`, `GeocodingService.enrichLocation`,
`HereRoutingService.getEtaMinutes`, and the Haversine `estimateEtaMinutes`
fallback (move the private helper into this service). Wire as a `ZLayer`.
**Then** refactor `DriverRoutes.scala` to call `EtaService.etaForRide` instead of
the inline block — keeps one source of truth.

### 2. New WebSocket event
**Edit:** `core/src/main/scala/com/shevchyk/core/domain/WebSocketEvent.scala`

```scala
final case class EtaAtRisk(
    rideId: UUID,
    driverId: UUID,
    clientId: UUID,
    etaMinutes: Int,
    minutesUntilPickup: Int,
    slackMinutes: Int,      // minutesUntilPickup - etaMinutes (negative = late)
    companyId: UUID
) extends WebSocketEvent
```
The derived `JsonEncoder/Decoder` (gen) picks it up automatically.

### 3. Alert dedup repository
**New:** `notification/.../EtaAlertRepository.scala` (+ Postgres impl) mirroring
`SentReminderRepository`: `isAlreadyAlerted(rideId, driverId): Task[Boolean]` /
`markAlerted(rideId, driverId): Task[Unit]`, plus a `clear(rideId)` to reset when
the ride changes (call from the same place `RideRepository.clearReminders` is
invoked on pickup-time change).
**New migration:** `api/src/main/resources/db/migration/V___Create_eta_alerts.sql`
— table `eta_alerts(ride_id, driver_id, alerted_at, ...)`, mirror
`sent_reminders`. Use the next free Flyway version number.

### 4. The monitor daemon
**New:** `api/src/main/scala/com/shevchyk/app/PredictiveEtaMonitor.scala`
— copy `ReminderScheduler`'s structure:

```scala
object PredictiveEtaMonitor:
  private val LookAheadMinutes = 45L
  private val RiskThresholdMinutes = 5  // alert if slack < 5 min

  def start: ZIO[RideRepository & EtaService & EtaAlertRepository & EventHub, Nothing, Unit] =
    val tick = checkAtRisk.catchAll(e => ZIO.logError(s"PredictiveEtaMonitor error: $e"))
    ZIO.logInfo("PredictiveEtaMonitor started") *>
      tick.repeat(Schedule.fixed(1.minute)).forkDaemon.unit
```

`checkAtRisk`: `findAssignedRidesInWindow(now, now + LookAhead)` → for each ride
with a driver, `etaForRide` → compute `slack` → if at risk and not already
alerted, `markAlerted` + `eventHub.publish(EtaAtRisk(...))`. Skip rides already
`InProgress`/`Completed` (window query already returns `Assigned` only).

### 5. Deliver the alert to dispatchers
**Edit:** `notification/.../PushNotificationListener.scala` — add an
`EtaAtRisk` branch in the event handler. Resolve the company's dispatchers
(`PersonRepository.findByRole(Dispatcher)` filtered by `companyId`) and, for each,
send an FCM push + persist an `AppNotification` (type `"eta_at_risk"`, title e.g.
"Ride at risk of delay", body with ETA vs pickup, `data.rideId`).
This also closes the existing gap noted in that file ("dispatcher notifications
currently only logged").

### 6. Wire into startup
**Edit:** `api/src/main/scala/com/shevchyk/Application.scala` — add
`PredictiveEtaMonitor.start *>` alongside the other daemons in `run`, and add the
`EtaService.layer` / `EtaAlertRepository.layer` to the layer composition.

## Configuration

Surface thresholds as config (env, like `HereConfig`) rather than hardcoding:
`ETA_MONITOR_LOOKAHEAD_MIN` (default 45), `ETA_MONITOR_RISK_THRESHOLD_MIN`
(default 5), `ETA_MONITOR_TICK_SECONDS` (default 60). Keeps tuning out of code.

## Testing (written and passing)

- **Unit — `EtaService`** (`driver/src/test/.../application/EtaServiceSpec.scala`,
  5 tests): HERE value used when present; Haversine fallback when HERE returns
  `None`; `None` when the driver has no location; `None` when the ride has no
  driver; live client location preferred over pickup coords.
- **Unit — `PredictiveEtaMonitor.tick`**
  (`api/src/test/.../app/PredictiveEtaMonitorSpec.scala`, 5 tests): exposes
  `private[app] def tick`. Slack below threshold → one `EtaAtRisk`; second tick →
  no duplicate (dedup repo); comfortable slack → no event; no ETA → no event;
  event carries the ride's own `companyId` (tenant isolation).
- **Unit — dispatcher delivery**
  (`notification/src/test/.../application/PushNotificationListenerSpec.scala`,
  +2 tests): `EtaAtRisk` alerts the company's dispatcher (`eta_at_risk`); does not
  alert the client.
- **Integration — `EtaAlertRepository` (Testcontainers + Postgres)**
  (`notification/src/test/.../integration/PostgresEtaAlertRepositorySpec.scala`,
  4 tests): `eta_alerts` migration applies; `markAlerted`/`isAlreadyAlerted`/`clear`
  round-trip; idempotent `markAlerted`; per-(ride, driver) granularity. DB is not
  mocked. (Required adding `core % "test->test"` + testcontainers deps to the
  `notification` module in `build.sbt`.)
- **Manual e2e** (not automated): `make dev`, create an assigned ride with a near
  pickup time and a driver location far from pickup, confirm an `EtaAtRisk` arrives
  over the WebSocket (`GET /api/ws`) and an `AppNotification` is persisted for the
  dispatcher.

## Future work (out of MVP scope)

- **Auto-suggest replacement** — nearest available driver from the own fleet
  (`DriverLocationService.findAvailableByCompanyId` already exists).
- **SLA dashboard** — % on-time rides, average delay per client company.
- **Schedule-aware risk** — also flag when ETA pushes the driver past the
  `ScheduleDay` `endTime`.
