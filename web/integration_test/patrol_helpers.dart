import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'package:oktopus/auth/login_screen.dart';

export 'patrol_test_app.dart';
export 'test_accounts.dart';

/// Shared Patrol helpers for the e2e_*_test.dart suites.
///
/// All E2E tests run against the full backend (Flyway dev-data) on TEST_PORT,
/// reached via `--dart-define=API_BASE_URL=...`. See the Makefile `e2e-*`
/// targets.

/// Base API URL the tests talk to (host reachable from the device/emulator).
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8090/api',
);

/// Resets transactional data via the dev-only `POST /api/dev/reset` endpoint.
///
/// Call this at the start of a mutating suite. It is what keeps the fast
/// single-bundle run (no test orchestrator → DB not wiped between tests)
/// isolated. No-op-safe: failures are swallowed so a missing endpoint or an
/// unreachable backend doesn't crash the test before it can skip.
Future<void> resetTestData() async {
  try {
    await http
        .post(Uri.parse('$kApiBaseUrl/dev/reset'))
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    // Ignore — the test's own skipIfBackendDown handles an unreachable backend.
  }
}

/// Logs in through the real login UI: fills email/password and taps "Sign In".
/// Waits for the login screen to disappear (navigation to a dashboard).
Future<void> loginViaUi(
  PatrolIntegrationTester $,
  String email,
  String password,
) async {
  // Wait for the login screen to appear (e.g. right after a logout).
  await $(LoginScreen).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(TextFormField).at(0).enterText(email);
  await $(TextFormField).at(1).enterText(password);
  await $('Sign In').tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 20));
}

/// Returns true (and marks the test skipped) when the app is still on the login
/// screen after a login attempt — i.e. the backend is unreachable or rejected
/// the credentials. Call right after [loginViaUi] and `return` if true.
bool skipIfBackendDown(PatrolIntegrationTester $) {
  if ($(LoginScreen).exists) {
    markTestSkipped(
      'Backend unavailable or login rejected — skipping E2E test. '
      'Start the full backend against the test DB (see `make e2e-android`).',
    );
    return true;
  }
  return false;
}

/// Logs out and returns to the login screen.
///
/// Two logout UIs exist:
///  - client/driver/secretary: a "Logout" button on the Settings tab, with a
///    confirmation dialog ("Logout").
///  - dispatcher/admin: a PopupMenuButton in the app bar with a "Logout" item.
///
/// We try the Settings-tab path first, then fall back to the app-bar menu.
Future<void> logoutViaUi(PatrolIntegrationTester $) async {
  // Reach the Settings screen, which differs per role:
  //  - client/driver/secretary: a "Settings" bottom-nav tab.
  //  - dispatcher/admin: "Settings" lives in the "More" menu grid.
  if (find.text('Settings').evaluate().isNotEmpty) {
    await tapNav($, 'Settings');
  } else if (find.text('More').evaluate().isNotEmpty) {
    await tapNav($, 'More');
    await $('Settings').scrollTo().tap();
    await $.pumpAndSettle();
  }
  await $.pump(const Duration(milliseconds: 500));

  // The "Logout" button sits at the bottom of the scrollable Settings list,
  // followed by a confirmation dialog whose button is also "Logout".
  await $('Logout').scrollTo().tap();
  await $.pumpAndSettle();
  final dialogLogout = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('Logout'),
  );
  if (dialogLogout.evaluate().isNotEmpty) {
    await $.tester.tap(dialogLogout.last, warnIfMissed: false);
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  }

  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}

/// Taps a bottom-navigation destination by its visible label.
///
/// Uses the raw `WidgetTester.tap` (via `$.tester`) rather than Patrol's
/// `tap`, because Patrol's strict visibility check (`waitUntilVisible`) times
/// out on bottom-nav labels that sit under full-screen PlatformViews
/// (Mapbox/Google maps) or nested Scaffolds. We tap the first matching label
/// directly and pump a few frames. `trySettle` avoids hanging on live maps.
Future<void> tapNav(PatrolIntegrationTester $, String label) async {
  // A lingering SnackBar can overlap the bottom nav and swallow taps. Dismiss
  // it first if present.
  final scaffolds = find.byType(Scaffold).evaluate();
  if (find.byType(SnackBar).evaluate().isNotEmpty && scaffolds.isNotEmpty) {
    ScaffoldMessenger.maybeOf(scaffolds.first)?.removeCurrentSnackBar();
    await $.pump(const Duration(milliseconds: 300));
  }

  final finder = find.text(label);
  if (finder.evaluate().isEmpty) {
    throw TestFailure('tapNav: no widget with text "$label" on screen');
  }
  // Tap the centre of the label's location. BottomNavigationBar labels sit
  // inside a larger tap target; tapping the exact label centre reliably hits
  // the destination's InkResponse, and `tapAt` ignores Patrol's strict
  // visibility checks that hang under PlatformViews (maps).
  final center = $.tester.getCenter(finder.first);
  await $.tester.tapAt(center);
  await $.pump(const Duration(milliseconds: 300));
  await $.pump(const Duration(milliseconds: 300));
}
