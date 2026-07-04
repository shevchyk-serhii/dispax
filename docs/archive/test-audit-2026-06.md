# Dispax Unit Test Audit — June 2026

## Summary

The backend is covered by **890 test cases across 76 files** on ZIO Test (Scala 3.3.7, ZIO 2.1.9).
Coverage is generally mature: the ride status machine, `CompanyId` isolation, validators,
repositories (in-memory + Testcontainers). The audit focused on **edge cases in
business- and security-critical logic**, where hidden bugs are possible.

### Statistics by module

| Module       | Files  | Test cases | Focus                                           |
|--------------|--------|------------|-------------------------------------------------|
| ride         | 20     | 288        | Lifecycle, assignment, revenue, chat, locations |
| api          | 13     | 165        | HTTP routes, integration                        |
| core         | 15     | 124        | Repositories, Audit, Geofence, EventHub         |
| auth         | 8      | 97         | JWT, rate limiting, middleware                  |
| schedule     | 6      | 74         | Schedule, validation                            |
| billing      | 5      | 64         | Invoices, PDF, DATEV                            |
| notification | 5      | 41         | FCM, orchestration                              |
| driver       | 4      | 37         | Location, routes                                |
| **Total**    | **76** | **890**    |                                                 |

---

## Coverage gaps found

Legend: ✅ closed by a new test · 🐛 bug-fix candidate (behavior needs a decision).

### 1. Ride — `RideServiceImpl`
`ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala`

- ✅ **Schedule conflict — interval boundary.** `ridesOverlap` (threshold `gap < 90 min`):
  there were tests for 10 min and 90 min, but no test exactly at the boundary (89/90/91 min) —
  a classic off-by-one.
- ✅ **Conflict without `scheduledTime`.** The fallback to `requestTime` was not covered.
- ✅ **`updateRideStatus` — Secretary/Client roles.** The method allows a status change only for
  Driver and Dispatcher; rejection for the other roles was not tested.
- ✅ **`updateRideStatus` → invalid target status** (`Requested`/`Assigned`):
  the `case target` → `InvalidStatusTransition` branch was not explicitly covered.
- ✅ **`earningsWindow`** — Week boundaries when `anchor = Sunday` and Month at the
  December→January boundary (year crossing via `plusMonths`).
- ✅ **`markPayment`** — `paidAt` is set only when the status is `Paid`; `paymentMethod = None`
  preserves the previous value.

### 2. Auth/JWT — `JwtServiceImpl`
`auth/src/main/scala/com/shevchyk/auth/service/JwtService.scala`

- ✅ **Absolute session expiry.** `refreshToken` must fail with `ExpiredTokenError` when
  `now - originalIat > maxSessionDuration` — previously not tested at all.
- ✅ **`originalIat` is preserved on refresh.** If it were updated the session would live
  forever (a security bug). The test pins its immutability.
- ✅ **Refresh of an expired token** → an error (via the internal `validateToken`).
- ✅ **issuer is validated in `validateToken`.** Previously a token with a foreign issuer but the
  same secret passed validation. Fixed: `validateToken` checks `claim.issuer` against the config
  and fails with `InvalidTokenError` on mismatch. **Note:** audience is not enforced — jwt-scala
  decodes a single `aud` back into `None`, so issuer is the reliable check.

### 3. Billing — `InvoiceServiceImpl.recalculate`
`billing/src/main/scala/com/shevchyk/billing/application/InvoiceService.scala`

- ✅ **Tax rounding.** Previously `tax = subtotal * taxRate / 100` was stored without rounding
  (`33.33 × 19% = 6.3327`), diverging from the PDF (2 decimals). Fixed: `recalculate` rounds
  `subtotalAmount`/`taxAmount`/`totalAmount` via `setScale(2, HALF_UP)`.
- ✅ **`taxRate = 0`** → `taxAmount = 0`, `total = subtotal`.
- ✅ **`autoFillFromPeriod` on a non-Draft** → `NotDraft`.

### 4. Geolocation / coordinate validation

- ✅ **lat/lng range validation.** Previously `ClientLocationService.updateClientLocation`,
  `DriverLocationService.updateLocation` and the DTO validators accepted any coordinates
  (it should be lat ∈ [−90, 90], lng ∈ [−180, 180]) — garbage reached the DB and broke
  Haversine/geofence. Fixed: a guard in `ClientLocationService` (`RideError.ValidationError`)
  and in `DriverLocationService` (`IllegalArgumentException`) + tests for rejection and boundaries.
- ✅ **`GeofenceService`** — a geofence with `radiusMeters = 0` (circle boundary; `distance < radius`
  is strict, so even at the center a driver is not "inside"). **Deduplication was already covered**
  by the existing "no duplicate entries on second call" and "no re-trigger for same threshold"
  tests — nothing needed to be added.
- ✅ **`DriverLocationService.checkGeofences`** — a driver with rides across different companies
  uses the companyId of the first ride (behavior pinned by a test).

---

## Bug fixes (all fixed)

1. ✅ **JWT issuer** — `validateToken` now rejects a token with a foreign issuer, even with the same
   secret (`InvalidTokenError`). Audience is not enforced due to a jwt-scala limitation (a single
   `aud` decodes into `None`). Tests: rejection by issuer + acceptance of a valid token.
2. ✅ **Tax rounding in InvoiceService** — `recalculate` rounds `subtotalAmount`/`taxAmount`/
   `totalAmount` to 2 decimals (`setScale(2, HALF_UP)`). Test: `33.33 × 19% → tax 6.33, total 39.66`,
   scale == 2.
3. ✅ **Coordinate validation in `DriverLocationService.updateLocation`** — a guard on the range
   lat ∈ [−90, 90] / lng ∈ [−180, 180]; on out-of-range, `IllegalArgumentException` (the method
   signature is `Task[Unit]`). Tests for rejection and for boundary values.
4. ✅ **`ClientLocationService.updateClientLocation`** — rejects out-of-range coordinates
   (`RideError.ValidationError`).

These items touch production logic and monetary/security invariants — they are listed
separately so the decision is made deliberately, rather than "on the fly" while editing tests.
