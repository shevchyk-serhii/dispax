import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:oktopus/dashboard/dashboard_screen.dart';

import 'patrol_helpers.dart';

/// E2E smoke test: logs in as a driver against the local `TestApplication`
/// backend and verifies the app reaches the authenticated dashboard.
///
/// Requires the backend running on :8080 (`sbt testServer`) and the API base
/// URL passed via `--dart-define=API_BASE_URL=...` (see the `patrol-test-*`
/// Makefile targets). If the backend is unreachable, the test is skipped.
void main() {
  patrolTest('driver logs in and reaches the dashboard', ($) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDriverEmail, kPassword);
    if (skipIfBackendDown($)) return;

    // Happy path: the dashboard replaced the login screen.
    expect($(DashboardScreen), findsOneWidget);
    expect($('Welcome Back'), findsNothing);
  });
}
