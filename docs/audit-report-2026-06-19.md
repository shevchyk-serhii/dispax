# Project Health Report — Dispax backend audit (2026-06-19)

Read-only audit: functional bugs, inconsistencies, SOLID & architecture violations,
security. Findings below were **verified against the actual code** (agent claims were
re-checked; false positives dropped, severities corrected).

## Summary
- **Compilation:** OK (all modules + Test/compile, exit 0)
- **Tests:** 1147 passed, 0 failed, 0 skipped (core 256, auth 137, ride 394, driver 54,
  notification 102, schedule 115, billing 89). BDD/Flutter not run here.
- **Requirements coverage:** 1 stated constraint not implemented (ScheduleDay) — see matrix
- **Security:** 0 HIGH exploitable, 3 LOW defense-in-depth gaps (tenant SQL hygiene)
- **Functional/SOLID:** 3 HIGH, ~7 MEDIUM verified

---

## HIGH — fix first

### H1. `getRidesForUser` drops rides for multi-role users  [Functional]
`ride/.../application/service/RideService.scala:170`
```scala
rideRepository.findByClientId(userId)
  .orElse(rideRepository.findByDriverId(userId))   // orElse = fallback on FAILURE, not union
```
`.orElse` returns driver rides **only if the client query fails**. For a dispatcher-who-drives
(a real, supported role — `roles=['dispatcher','driver']`), a successful client query means
driver rides are silently never returned. **Fix:** union the two lists and `distinctBy(_.id)`
(the GDPR export already does exactly this — reuse that shape).

### H2. `assignDriver` never validates the ScheduleDay  [Functional / requirement gap]
`ride/.../application/service/RideService.scala` (assignDriver) — `grep scheduleDay` in the
service is empty. CLAUDE.md constraint #3 ("an assignment must reference a valid ScheduleDay")
is **not enforced**: a ride carrying a `scheduleDayId` can be assigned even if that day is
missing/cancelled or belongs to another driver. **Fix:** when `ride.scheduleDayId.isDefined`,
load it via the schedule module and fail (`BusinessRuleViolation`) if absent / not the driver's
/ not active.

### H3. ChatService uses `Task` + `RuntimeException` instead of typed errors  [Architecture/DIP]
`ride/.../application/service/ChatService.scala:10-12` and impl.
```scala
def sendMessage(...): Task[ChatMessage]
... ZIO.fromOption(rideOpt).orElseFail(new RuntimeException("Ride not found: ..."))
... ZIO.fail(new RuntimeException("Chat is only available for active rides"))
```
Violates the project rule "ZIO typed effects, no untyped throwables in the domain". Callers
can't pattern-match failures; the HTTP layer can't map them precisely. **Fix:** introduce
`sealed trait ChatError` (RideNotFound, ChatNotAvailable) and `IO[ChatError, _]`.

---

## MEDIUM

### M1. `InvoiceStatus.fromString` silently defaults to `Draft`  [Functional/data integrity]
`billing/.../domain/Invoice.scala` — `case _ => Draft`. Used when reading status **from the DB**
(`PostgresInvoiceRepository.scala:82`). A corrupted/unknown status is silently read as `Draft`,
so a Paid/Sent invoice could be treated as an editable draft. **Fix:** return `Option`/`Either`
and fail loudly (or log) on unknown; the JSON codec already rejects unknown values on input, so
this is also a consistency issue.

### M2. Non-exhaustive `PersonRole` match in `validateCancelPermission`  [Functional]
`ride/.../application/service/RideService.scala` — handles Dispatcher/Secretary/Admin/
ClientSecretary/SuperAdmin (allow), Client, Driver; **no `case _`**. A future role would hit a
`MatchError` at runtime. **Fix:** add an explicit deny `case _`.

### M3. Notification/event/audit failures swallowed after assign  [Functional/observability]
`RideService.assignDriver` — `eventHub.publish(...).ignore`, `emailSmsService.send...().ignore`,
`auditService.log(...).ignore`. A ride is assigned but the driver may never be notified, with no
surfaced alert; the event-hub call has no `tapError` at all. **Fix:** keep the "don't fail the
request" intent but `.tapError(logWarning)` consistently on all three; consider a metric for
notification failures.

### M4. Negative/zero pagination not validated  [Functional/robustness]
`ride/.../openapi/RideApi.scala` listRides — `offset`/`limit` passed straight to SQL with only
`getOrElse` defaults; `limit=-1` / `offset=-10` reach Doobie unchecked. **Fix:** clamp/validate
(`limit in 1..200`, `offset >= 0`) in the handler or a shared `PageRequest`.

### M5. RideService is a god-object (SRP/ISP)  [Architecture]
`RideService` trait = 27 methods / ~786 lines mixing CRUD, status machine, **stats**
(revenue/earnings/daily), **payments**, and company queries. `RideRepository` = 29 methods,
same spread. Any consumer needing `getRideById` depends on all 27. **Fix (incremental):** split
stats (`RideStatsService`/`RideStatsRepository`) and payment off the core ride service.

### M6. Duplicated infrastructure across modules  [Architecture/DRY]
- `Validator` trait duplicated verbatim: `ride/.../validation/Validator.scala` &
  `schedule/.../validation/Validator.scala` → move to `core`.
- Two different `ClientCompanyRepository` traits (core vs billing) with **divergent signatures**
  for the same concept → reconcile to one.
- DATEV CSV generation copied into `ride/.../openapi/ExportApi.scala` ("copied here so the same
  byte-for-byte output is produced") → extract a `DatevCsvGenerator`.
- `checkRole`/`checkRoleOrOwner`/`requireCompanyId` re-defined in `RideSecure` and `UserApi`
  (and per-module `*Secure`) → hoist to a shared `core` helper.

### M7. Business logic in HTTP handlers  [Architecture/DIP]
`ride/.../openapi/RideApi.scala` createRide: role→clientId override (CLIENT/DRIVER can only
create for self) lives in the handler; rating 1..5 validated in the handler. Belongs in the
application/validator layer.

---

## LOW — defense-in-depth / hygiene

### L1. Self-data repo reads without company filter  [Security: low, not exploitable]
`GdprApi.scala` (export) and `ExpenseApi.scala:83` call `findByClientId/findByDriverId(user.userId)`
without a company filter. **Verified low:** `Person.companyId` is a single `Option[CompanyId]`
and `persons.id` is a UUID PK, so one PersonId ⇒ one company — a user only ever sees their own
single-company data. Still worth switching to the `*AndCompany` variants for defense-in-depth.

### L2. Unfiltered repo methods invite future tenant bugs  [Security: low]
`PostgresRideRepository.findAll/findByClientId/findByDriverId` and
`PostgresExpenseRepository.findByDriverId` have no `company_id` in WHERE. Not reachable as a
cross-tenant leak today (callers pass the user's own id), but a trap. **Fix:** add the filter or
deprecate in favour of `*AndCompany`. (Billing's update/delete/replaceItems/unlinkRides were
checked and **do** filter by `taxi_company_id` — good.)

### L3. `PaymentChecker` is a permanent mock  [Functional/known]
`billing/.../application/PaymentChecker.scala` — `isPaid` always `false` by design; auto-
reconciliation never happens, only manual `markPaid`. Known/intentional, documented so it's not
mistaken for a bug.

### L-minor
- `InvoiceStatus.fromString` vs JSON codec: two parsing policies (silent-default vs reject) —
  unify (ties to M1).
- `DriverApi` status check uses string compare (`!= "Available" && != "Offline"`) instead of an
  enum.
- `auth/.../openapi/AuthApi.scala` login error map `case _ => Internal` catch-all — fine for
  security, but hides new `AuthError` cases.

---

## Requirements Coverage Matrix (key constraints, CLAUDE.md §Business Rules)

| Constraint | Code | Tests | Status |
|---|---|---|---|
| 1. Companies isolated; drivers assigned only to own-company rides | yes (assignDriver company_isolation guard) | yes | COVERED |
| 2. Only `Requested` ride can be assigned | yes (`canBeAssigned`, atomic `updateIfStatus`) | yes | COVERED |
| 3. Assignment must reference a valid ScheduleDay | **no** | no | **MISSING (H2)** |
| 4. Travel time via Google API to validate schedule | partial (HERE-based ETA monitor; assign-time check uses a flat overlap heuristic, not real ETA) | partial | PARTIAL |
| 5. Client doesn't wait — punctuality > utilization | partial (predictive ETA monitor) | partial | PARTIAL |
| 6. Rides created by secretary/dispatcher/driver/client | yes | yes | COVERED |

---

## Recommended Actions (priority)
1. **H1** `getRidesForUser` union fix — small, real data-loss bug; regression-test home in `RideServiceSpec`.
2. **H2** ScheduleDay validation on assign — closes the one missing stated constraint.
3. **H3** ChatService typed errors — architectural correctness, isolated blast radius.
4. **M1/M2** loud-fail on unknown InvoiceStatus + exhaustive role match — cheap, prevents silent corruption / MatchError.
5. **M3/M4** consistent `.tapError` on notifications + pagination clamping.
6. **M5/M6/M7** architecture cleanup (god-object split, de-dup Validator/ClientCompanyRepo/DATEV/secure-helpers) — a `chore/` refactor, not urgent.
7. **L1/L2** switch self-data reads to `*AndCompany`, filter/deprecate unfiltered repo methods.

Each fix that touches a code path needs a covering test first (CLAUDE.md bug→test rule).
