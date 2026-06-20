# Review: DRIVER-phase design restyle (4 driver screens)

## Verdict: FAIL

---

## Invariant checklist

1. **Tenant isolation** [CRITICAL/SECURITY] — OK. Flutter screens are read-only consumers of authenticated BLoC state; no CompanyId filtering is done here (backend enforces it). No regression introduced.
2. **ZIO-only** — OK (Flutter-only change; invariant applies to backend).
3. **Clean handlers** — OK (Flutter-only change).
4. **Integration tests** — OK (Flutter-only change; Testcontainers rule is backend).
5. **Secrets** — OK. No hardcoded secrets.
6. **DTO ≠ domain** — OK.
7. **Ride status machine** — OK. Status transitions (Requested→Assigned→InProgress→Completed/Cancelled) preserved via `RideStatusUpdateRequested` dispatches.

**Testing invariant (required unit test per new business branch):** VIOLATED — see F4 below.

---

## Findings (ranked by severity)

### F1 — Dark-mode breakage: `_EtaChip` hardcoded light colors (FAIL)
**`web/lib/dashboard/driver/today_rides_screen.dart:1284–1302`**

The new `_EtaChip` widget uses fully hardcoded light-mode colors:
- Container fill: `const Color(0xFFF0F9FF)` — opaque light-sky-blue
- Border: `const Color(0xFFBAE6FD)`
- Text: `const Color(0xFF075985)` — dark blue

This chip sits inside a `_LiveRideCard` whose background comes from `AppStyles.primaryCardDecorationOf(context)` (correctly switches to `AppColors.surfaceDark` in dark mode). In dark mode, the opaque light-blue chip glows on a graphite card with dark-blue text — the chip is legible but severely jarring and inconsistent with the theme-aware design applied everywhere else in the same file. This is a new widget that does not exist in master; the regression is introduced by this PR.

### F2 — Earnings screen removes stat tiles backed by real API data (moderate)
**`web/lib/dashboard/driver/earnings_screen.dart`** — removed `_buildMetricsGrid`

The master screen displayed three stat tiles from `DriverEarnings` model fields: `completedRides`, `cancelledRides`, and `avgFare`. These fields come directly from the backend (`/driver/earnings` endpoint) and are mapped in `DriverEarnings.fromJson` (model at `web/lib/modules/ride_management/models/driver_earnings.dart:24–26`). The new redesign drops this widget entirely without replacement. The fields are still fetched (the cubit still calls the same endpoint), but the data is now silently discarded. Drivers lose visibility into their ride counts and average fare.

This is a product regression, not a dark-mode issue — the data is real and was intentionally shown before.

### F3 — Dark-mode: `upcoming_rides_screen.dart` pickup time uses hardcoded light-mode color (minor)
**`web/lib/dashboard/driver/upcoming_rides_screen.dart:312`**

```dart
color: AppColors.textSecondary,  // 0xFF71717A — zinc-500, light-mode only
```

The pickup time label inside each upcoming ride card uses `AppColors.textSecondary` (hardcoded light-mode constant) instead of `colorScheme.onSurfaceVariant`. The card background is `colorScheme.surface` (theme-aware). In dark mode the card background is near-black and `AppColors.textSecondary` (mid-grey `#71717A`) renders with reduced but non-zero contrast. Not a crash, but inconsistent with the `colorScheme.onSurfaceVariant` pattern used for the route text and detail line in the same card (lines 323, 337).

Also at `upcoming_rides_screen.dart:92`: "Next 7 days" header subtitle in the graphite header uses `AppColors.textSecondary`. That one is fine — it's intentionally the same grey used by other graphite-header subtitles (`textSecondary` on graphite is the design-system pattern used consistently across all four screens).

### F4 — No tests added for new business logic (testing invariant violated)
**No files in `web/test/`**

Two new stateful widgets introduce business logic that has no widget test coverage:

1. `_AvailabilityPill` (`today_rides_screen.dart:586`) — makes its own `apiClient.get/put` calls outside the BLoC layer (inline service calls to `/drivers/{id}/availability`). This is also an architectural deviation: the CLAUDE.md convention is "BLoC pattern for all state, a `Repository` abstraction for API calls" — inline `apiClient` calls in a widget are not the established pattern. The existing `web/test/widgets/availability_toggle_test.dart` covers the old `AvailabilityToggle` widget; the new `_AvailabilityPill` is untested.

2. `_EmbeddedHistoryTab` — new widget with its own filtering and empty-state logic; no test.

The dev-flow config states: "a unit test (in-memory double) for every new business branch in the application layer." The `_AvailabilityPill` is a UI widget, not strictly application layer, but it contains HTTP logic that belongs there.

### F5 — `_EmbeddedHistoryTab` has no refresh trigger (minor UX gap)
**`today_rides_screen.dart:1519–1576`**

The embedded History tab inside the segmented control reads from the existing `RideBloc` state without triggering a load if the state is `initial`. The `_EmbeddedUpcomingTab` (line 1506) delegates to `UpcomingRidesScreen().buildBody()` which correctly calls `loadUpcomingRides` on `RideStateStatus.initial`. The embedded History tab has no equivalent trigger and no refresh button. In the common case (user landed on Today first) the data is already loaded, so this is normally invisible — but on a cold start to the History tab via the segmented control the list shows empty with no way to refresh.

### F6 — `_AvailabilityPill` bypasses BLoC architecture (minor / architectural debt)
**`today_rides_screen.dart:604–647`**

The pill calls `context.read<AuthBloc>().apiClient` directly and makes raw `GET`/`PUT` calls. The established pattern (CLAUDE.md: "Flutter: BLoC pattern for all state, a `Repository` abstraction for API calls") means this should go through `DriverBloc` + a `DriverRepository`. The old `AvailabilityToggle` widget (which this replaces) did the same thing, so this is not a new regression in pattern, but it is perpetuated by the redesign instead of corrected.

---

## Check: preserved behavior in `today_rides_screen.dart`

All critical logic items confirmed preserved:

| Item | Status |
|------|--------|
| `_wsSubscription` (`isDriverApproaching` → `_approachingDistances`, `isRideAssigned` → dialog) | PRESERVED (lines 64–77) |
| 90-second `_etaTimer` + `_refreshEta` | PRESERVED (lines 80–103) |
| Location tracking start/stop/send with 10-second throttle | PRESERVED (lines 165–200) |
| Ride-assigned accept/decline dialog + dispatch | PRESERVED (lines 106–146) |
| `_handleStartRide` → `RideStatusUpdateRequested(inProgress)` + `_startLocationTracking` | PRESERVED (lines 527–532) |
| `_handleCompleteRide` → confirm dialog → `RideStatusUpdateRequested(completed)` + `_stopLocationTracking` | PRESERVED (lines 535–565) |
| `_handleCallClient` → phone check → `_showContactOptions` | PRESERVED (lines 483–524) |
| `_startLocationTracking` auto-restored on bloc reload when `hasActiveRide` | PRESERVED (lines 237–243) |
| `dispose` cancels WS + timer + location | PRESERVED (lines 155–162) |

---

## Status badge check

All status badges in all four files use `RideStatusStyles`:
- `_LiveRideCard` and `_NextRideCard`: use `RideStatusStyles.getStatus*` with `brightness` passed — theme-aware. OK.
- `ride_history_screen.dart` cards: use `RideStatusStyles.createStatusBadge(context: context)` — theme-aware. OK.
- `upcoming_rides_screen.dart` cards: use `RideStatusStyles.createStatusBadge(context: context)` — theme-aware. OK.

---

## Bloc/data wiring check

| Screen | Wired correctly |
|--------|----------------|
| Earnings period chips (Day/Week/Month) → `cubit.setPeriod` | YES (`earnings_screen.dart:165`) |
| Earnings prev/next nav → `cubit.prevPeriod` / `cubit.nextPeriod` | YES (lines 199, 219) |
| Earnings gross/net revenue values from `state.data` | YES (lines 51, 545) |
| History period filter updates list | YES (`_period` setState → `getCompletedRides` filter) |
| History rating display | YES (line 377 `_averageRating`) |
| History tap-to-detail → `RideDetailsScreen` | YES (`ride_history_screen.dart:491`) |
| Upcoming `groupRidesByDate` + refresh | YES (`upcoming_rides_screen.dart:138, 144`) |

---

## Documentation

N/A — this change is purely Flutter widget restyling; no API endpoints, CLI flags, config vars, DB schema, or architecture docs are affected.

---

## To fix (mandatory before PASS)

**F1 (blocking):** Replace hardcoded colors in `_EtaChip` with theme-aware values. Use `colorScheme.primaryContainer` / `colorScheme.onPrimaryContainer` or equivalent `AppColors` token pairs that have dark-mode variants, matching the pattern used in the rest of the file.

**F4 (blocking):** Add widget tests for `_AvailabilityPill` (toggle on/off, error state) and `_EmbeddedHistoryTab` (empty state, populated state). The existing `availability_toggle_test.dart` can serve as a template.

**F2 (recommended):** Restore the `completedRides` / `cancelledRides` / `avgFare` stat tiles removed from `earnings_screen.dart`, or add them to the new `_DailyBreakdownCard` / summary row so real backend data is not silently discarded.

**F3 (cosmetic, recommended):** Change `upcoming_rides_screen.dart:312` `color: AppColors.textSecondary` to `color: colorScheme.onSurfaceVariant` for consistency with surrounding card text.
