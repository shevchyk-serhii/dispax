import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Smoke e2e for the driver Upcoming segment.
///
/// The Upcoming screen rendered its error message with `errorMessage!`, which
/// crashed the screen whenever an error RideState arrived with a null message
/// (reachable via copyWith scoping). That null-message crash is pinned by the
/// unit test `test/dashboard/upcoming_rides_error_test.dart`; this e2e simply
/// confirms the Upcoming segment opens and renders against a live backend
/// without throwing.
void main() {
  patrolTest('driver opens the Upcoming segment without crashing', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Driver lands on the Today ("My Rides") screen. Switch to the Upcoming
    // segment of its segmented control.
    await $.pump(const Duration(seconds: 2));
    await $.tester.tap(
      find.textContaining('Upcoming').first,
      warnIfMissed: false,
    );
    await $.pump(const Duration(seconds: 2));

    // No exception was thrown switching to / rendering the Upcoming segment, and
    // we are still inside the app (not bounced to login by a crash).
    expect($('Sign in'), findsNothing);
    expect($.tester.takeException(), isNull);
  });
}
