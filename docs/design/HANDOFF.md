# Dispax — Developer Handoff (Flutter · iOS + Android)

Companion to **`Dispax Design.dc.html`** (open it for the pixel reference). This doc maps every
design decision to your existing Flutter code so implementation is 1:1, and calls out everything
needed to ship on **iPhone and Android** from one codebase.

> **Source of truth.** Layout, spacing and composition → read the HTML. Code values → the tables
> below, which point at your existing `AppColors`, `AppStyles`, `AppDimensions`. Where the design
> uses a value that has no constant yet, it's flagged **(new)** with a recommendation.

---

## 1. How to use this handoff

1. The visual style is the **graphite system already in `app_colors.dart`** — graphite `#18181B`
   base + single Sky-cyan accent `#0EA5E9`. Role is shown by **icon + label, not color**. Nothing
   new to define in code — reuse `AppColors`.
2. Build screens with the existing constants (`AppColors` / `AppStyles` / `AppDimensions`). Only a
   handful of **(new)** tokens are introduced; add them once, listed in §10.
3. Every screen below names the **existing Dart file** it refines, so this is a restyle, not a
   rewrite.

---

## 2. Platform targets — one codebase, iPhone + Android

| Concern                                     | iOS                                       | Android                      | Implementation                                                                                              |
|---------------------------------------------|-------------------------------------------|------------------------------|-------------------------------------------------------------------------------------------------------------|
| Status bar over graphite header             | light icons                               | light icons                  | `AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light)` on header screens                |
| Top inset (Dynamic Island / notch / cutout) | 47–59 px                                  | 24–48 px                     | Wrap headers in `SafeArea(bottom:false)` — **never hard-code 44**. Use `MediaQuery.viewPadding.top`         |
| Bottom inset (home indicator / gesture bar) | ~34 px                                    | 0–48 px                      | `SafeArea(top:false)` around bottom nav; design's 20 px bottom pad is **on top of** the safe area           |
| Back navigation                             | edge-swipe                                | system back button           | `PopScope` (replaces `WillPopScope`) — already used for the "Discard changes?" guard                        |
| Switch / dialog / spinner look              | Cupertino                                 | Material                     | Use `.adaptive` constructors: `Switch.adaptive`, `showAdaptiveDialog`, `CircularProgressIndicator.adaptive` |
| Fonts                                       | Inter **not** preinstalled                | Inter **not** preinstalled   | **Bundle Inter in `pubspec.yaml`** (see §9). Do not rely on the system font                                 |
| Push notifications                          | APNs key + capability + permission prompt | FCM token                    | `firebase_messaging`; map the `eta_at_risk` payload type to the dispatcher alert                            |
| Maps                                        | needs iOS API key in `AppDelegate`        | key in `AndroidManifest.xml` | `google_maps_flutter` (or Mapbox) — see §6 Client tracking                                                  |
| Haptics                                     | Taptic                                    | vibrate                      | `HapticFeedback.selectionClick()` on assign / accept / toggle                                               |

> **Golden rule:** the phone frame in the HTML shows a Dynamic Island and a 44 px status bar for
> *presentation only*. In Flutter, all top/bottom spacing comes from `SafeArea` + `MediaQuery`, so
> it adapts to every iPhone and Android device automatically.

---

## 3. Colors → `AppColors`

All already exist — reuse them, do not introduce new hexes.

| Design                      | Hex                   | Flutter constant                              |
|-----------------------------|-----------------------|-----------------------------------------------|
| Graphite base / primary     | `#18181B`             | `AppColors.primary`                           |
| Graphite 950 / dark         | `#09090B`             | `AppColors.primaryDark` / `brand900`          |
| Graphite 700                | `#3F3F46`             | `AppColors.primaryLight` / `brand600`         |
| **Accent (Sky)**            | `#0EA5E9`             | `AppColors.accent`                            |
| Accent light / dark         | `#38BDF8` / `#0284C7` | `AppColors.accentLight` / `accentDark`        |
| Page background             | `#FAFAFA`             | `AppColors.background`                        |
| Card surface                | `#FFFFFF`             | `AppColors.surface`                           |
| Subtle section / input fill | `#F4F4F5`             | `AppColors.surfaceVariant` / `primarySurface` |
| Border                      | `#E4E4E7`             | `AppColors.borderPrimary`                     |
| Border strong (inputs)      | `#D4D4D8`             | `AppColors.borderSecondary`                   |
| Text primary                | `#18181B`             | `AppColors.textPrimary`                       |
| Text secondary              | `#71717A`             | `AppColors.textSecondary`                     |
| Text tertiary / hint        | `#A1A1AA`             | `AppColors.textLight`                         |

**Ride status** (functional, role-independent — use `RideStatusStyles` + `utils/ride_status_styles.dart`):

| Status      | Dot/main  | BG        | Border    | Text      | Constants         |
|-------------|-----------|-----------|-----------|-----------|-------------------|
| Requested   | `#F59E0B` | `#FFFBEB` | `#FCD34D` | `#92400E` | `rideRequested*`  |
| Assigned    | `#3B82F6` | `#EFF6FF` | `#93C5FD` | `#1E40AF` | `rideAssigned*`   |
| In progress | `#14B8A6` | `#F0FDFA` | `#5EEAD4` | `#115E59` | `rideInProgress*` |
| Completed   | `#22C55E` | `#F0FDF4` | `#86EFAC` | `#166534` | `rideCompleted*`  |
| Cancelled   | `#EF4444` | `#FEF2F2` | `#FCA5A5` | `#991B1B` | `rideCancelled*`  |

Dark-mode variants already exist (`*BgDark`, `*TextDark`) — wire them via `Theme.of(context).brightness`.

---

## 4. Typography → `AppStyles` (font: Inter)

| Design role            | Size / weight | Flutter style              | Note                                                                           |
|------------------------|---------------|----------------------------|--------------------------------------------------------------------------------|
| Display (hero numbers) | 36 / 700      | `AppStyles.headlineLarge`  | constant is 32 — bump to 36 for hero ETA/stat, or add **(new)** `displayLarge` |
| H1 page title          | 28 / 700      | `AppStyles.headlineMedium` | exact match                                                                    |
| H2 section             | 22 / 600      | `AppStyles.titleLarge`     | constant is 20 — use 22 via `.copyWith(fontSize:22)`                           |
| H3 card title          | 18 / 600      | `AppStyles.titleMedium`    | exact match                                                                    |
| Body L                 | 16 / 400      | `AppStyles.bodyLarge`      | exact match                                                                    |
| Body M                 | 14 / 400      | `AppStyles.bodyMedium`     | exact match                                                                    |
| Body S / caption       | 12 / 400      | `AppStyles.bodySmall`      | exact match                                                                    |
| Label (buttons/nav)    | 14 / 600      | `AppStyles.labelLarge`     | constant weight is 500 — design uses 600                                       |
| Label S (uppercase)    | 11 / 600      | `AppStyles.labelSmall`     | add `letterSpacing` for the uppercase eyebrows                                 |

Headings use **negative tracking** (`letterSpacing: -0.3…-0.5`) — already in `AppStyles`.

---

## 5. Spacing, radius, elevation, buttons → `AppDimensions` / `AppStyles`

**Spacing (4 px base):**

| Design px | Constant                                          |
|-----------|---------------------------------------------------|
| 4         | `paddingXSmall`                                   |
| 8         | `paddingSmall` / `smallSpacing`                   |
| 12        | **(new)** — use literal `12` (list-item gap)      |
| 16        | `paddingMedium` / `screenPadding` / `itemSpacing` |
| 24        | `paddingLarge` / `sectionSpacing`                 |
| 32        | `paddingXLarge`                                   |
| 48        | `paddingXXLarge`                                  |

**Radius:**

| Design        | Constant                                         | Used for                                                |
|---------------|--------------------------------------------------|---------------------------------------------------------|
| pill / 9999   | `StadiumBorder()` / `BorderRadius.circular(999)` | status badges, search field, online pill, avatars       |
| 10 (buttons)  | `radiusMedium` (12)                              | keep 12 for reuse, or add **(new)** `radiusButton = 10` |
| 12            | `radiusMedium`                                   | inputs, small cards, stat tiles                         |
| 14–16 (cards) | `radiusLarge` (16)                               | ride cards, panels, windows                             |
| 20 / 30       | `radiusXLarge` / `radiusXXLarge`                 | hero cards, bottom-sheet top                            |

**Elevation — shadows, not borders, carry depth** (`AppColors.shadow*` + `AppStyles.primaryCardDecoration`):

| Level             | BoxShadow                     | Use                                                   |
|-------------------|-------------------------------|-------------------------------------------------------|
| xs                | `0 1px 2px rgba(0,0,0,.05)`   | inputs, mini tiles (`shadowXs`)                       |
| sm (default card) | `0 1px 3px / 0 1px 2px`       | every card (`glassCardDecoration`)                    |
| md                | `0 4px 12px rgba(0,0,0,.08)`  | live/active card, dropdowns (`primaryCardDecoration`) |
| lg                | `0 8px 24px rgba(0,0,0,.12)`  | bottom sheet, modals                                  |
| xl                | `0 16px 48px rgba(0,0,0,.16)` | overlay panels                                        |

**Buttons** (min height 44 for touch; design uses 44 mobile / 40 desktop):

| Variant                  | Widget + style                                                        | Notes                                                           |
|--------------------------|-----------------------------------------------------------------------|-----------------------------------------------------------------|
| Primary (graphite)       | `ElevatedButton` + `AppStyles.primaryButtonStyle`                     | bg `primary`, radius 12, height `buttonHeightMedium` (48) or 44 |
| **Accent (live action)** | `FilledButton` bg `AppColors.accent`, white fg                        | **(new)** — Track / Navigate / Call-driver only; one per screen |
| Secondary                | `OutlinedButton` + `AppStyles.outlinedButtonStyle`                    | white bg, `borderSecondary`                                     |
| Ghost                    | `TextButton` + `AppStyles.textButtonStyle`                            | —                                                               |
| Destructive              | `OutlinedButton` fg `error` (soft) / `FilledButton` bg `error` (hard) | Cancel / Emergency reassign                                     |

---

## 6. Components → Flutter widgets

| Component (in HTML)                | Flutter widget                                             | Notes                                                                                    |
|------------------------------------|------------------------------------------------------------|------------------------------------------------------------------------------------------|
| Status badge                       | `Container` + `StadiumBorder` + dot                        | drive from `RideStatusStyles.getStatusColor/Icon`                                        |
| Segmented (Today/Upcoming/History) | `CupertinoSlidingSegmentedControl` or M3 `SegmentedButton` | adaptive feel                                                                            |
| Availability toggle                | `Switch.adaptive` (active = `accent`)                      | online/offline                                                                           |
| Stat tile                          | `Container` (graphite or `surfaceVariant`)                 | hero number = `headlineMedium`+                                                          |
| Search field                       | `TextField` + `AppStyles.textFieldDecoration`              | pill variant = `StadiumBorder`                                                           |
| Ride card                          | `Card` + `Column`/`ListTile`                               | matches `MyRidesTab` today                                                               |
| Route connector (origin→dest)      | `Column` with dot · line · square                          | dot = accent ring, dest = graphite square                                                |
| Driver bottom sheet (client)       | `showModalBottomSheet` / `DraggableScrollableSheet`        | rounded top `radiusXLarge`                                                               |
| Lifecycle stepper                  | custom `Column` (dot + connector) or `Stepper`             | current step = teal pulsing dot                                                          |
| Bottom nav                         | `BottomNavigationBar` (type fixed)                         | `selectedItemColor: AppColors.accent`, height `bottomNavHeight` (80), `Icons.*_outlined` |
| Sidebar (desktop ≥800)             | `NavigationRail` or custom graphite column                 | active item = accent left bar + accent icon                                              |
| Predictive-ETA alert               | `Container` red-left-accent card                           | see §7                                                                                   |
| Live map                           | `GoogleMap`                                                | custom marker = driver; `Polyline` = route; pin = destination                            |

> **Icons:** the HTML uses Lucide-style strokes for clarity. In Flutter, keep your current
> **Material outlined** icons (`Icons.today_outlined`, `Icons.map_outlined`, …) for consistency, or
> add the `lucide_icons` package if you want an exact match. Stroke weight ≈ 2.

---

## 7. Screen-by-screen → existing Dart files

| Design screen              | Refines                                                                      | Key widgets / behavior                                                                                                                                               |
|----------------------------|------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Driver — Today**         | `dashboard/driver/today_rides_screen.dart`                                   | SafeArea graphite header, availability `Switch.adaptive`, live ride `Card` with ETA chip + flight, `BottomNavigationBar`. ETA polled every 90s (already implemented) |
| **Client — Live tracking** | `screens/client_map_screen.dart` + `client_dashboard.dart`                   | `GoogleMap` full-bleed, floating back + status pill, `DraggableScrollableSheet` driver card with ETA, Call/Message. Airport entry timer card stays                   |
| **Ride lifecycle**         | `screens/ride_details_screen.dart` (`RideStatusCard`)                        | vertical stepper for `Requested→Assigned→InProgress→Completed`; current step animated; slack/ETA chip                                                                |
| **Dispatcher board**       | `dashboard/dispatcher/dispatcher_dashboard.dart` (`PendingRidesPanel`)       | **≥800 = `NavigationRail` + split**, <800 = bottom nav. Stats row, pending-requests list with Assign, live-fleet panel                                               |
| **Predictive ETA alert**   | `archive/feature-predictive-eta-monitoring.md` → consumes `WebSocketEvent.EtaAtRisk` | red-left card: Driver ETA vs Pickup-in vs **Slack (negative)**; Reassign / View. Shown on `eta_at_risk` push + WS event for the company's dispatchers                |
| **Billing**                | `screens/billing_screen.dart` + `datev_export_screen.dart`                   | stats, invoice `DataTable`/list, status pills, **Export DATEV** (GoBD CSV). EUR formatting via `intl`                                                                |

---

## 8. States, motion, a11y

- **Tap states:** cards `scale(0.98)` + shadow drop; buttons darken 10 %; nav items instant color.
  Use `AnimatedScale` / `InkWell`.
- **Durations:** `AppDimensions.animationFast` (150) hover/color · `animationMedium` (300) layout/reveal
  · `animationSlow` (500) page transitions. Easing `Curves.easeInOutCubic`.
- **Live indicators:** pulsing dot (driver marker, "live now", in-progress step) = scaling
  `AnimationController` repeat. Keep subtle.
- **Touch targets ≥ 44×44** on both platforms.
- **Localization:** all strings via existing `l10n/` (DE / EN / UK) — no hard-coded copy. German
  examples in the mockups (München, Hbf, DATEV, €) are realistic placeholders.

---

## 9. `pubspec.yaml` — bundle Inter (required on iOS **and** Android)

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf      # w400
        - asset: assets/fonts/Inter-Medium.ttf        # w500
        - asset: assets/fonts/Inter-SemiBold.ttf      # w600
        - asset: assets/fonts/Inter-Bold.ttf          # w700
```
Set `ThemeData(fontFamily: 'Inter')`. Neither iOS nor Android ships Inter, so without this the app
falls back to San Francisco / Roboto and the type scale shifts.

---

## 10. New tokens to add (one-time)

```dart
// AppColors — none (accent already exists)

// AppStyles
static ButtonStyle accentButtonStyle = FilledButton.styleFrom(
  backgroundColor: AppColors.accent,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
  ),
);

// AppDimensions (optional, if you want exact button radius)
static const double radiusButton = 10.0;
static const double breakpointDesktop = 800.0; // matches dispatcher LayoutBuilder
```

---

## 11. Responsive — the 800 px breakpoint (web + desktop)

Your `dispatcher_dashboard.dart` already switches at `constraints.maxWidth >= 800`. Apply the same
rule to **every** role for web/desktop:

- **< 800** → mobile: graphite header + `BottomNavigationBar`, single column, `screenPadding` 16.
- **≥ 800** → desktop/web: graphite **`NavigationRail`/sidebar** (bottom nav hidden), content centered
  at `maxContentWidth` (1200), multi-column / master-detail. Client tracking becomes map-left +
  driver-panel-right instead of a bottom sheet; Driver "Today" becomes list-left + ride-detail-right.

Wrap the root in `LayoutBuilder`; share the same widgets, swap only the navigation chrome and column
count. This keeps iPhone, Android, web and desktop on one codebase and one design system.
