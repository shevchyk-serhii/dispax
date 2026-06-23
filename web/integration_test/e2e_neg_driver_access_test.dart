import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// NEGATIVE (role access): a driver cannot see dispatcher/admin navigation.
///
/// A driver's dashboard exposes only Today / Calendar / Book / Map / Settings.
/// The dispatch board, the More admin grid, analytics and billing must not be
/// reachable from the driver UI.
void main() {
  patrolTest('driver cannot see dispatcher or admin navigation', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // The driver dashboard runs perpetual animations (pulse controller), so a
    // plain settle would time out — pump a few frames to let it render instead.
    await $.pump(const Duration(seconds: 2));

    for (final forbidden in const [
      'New Ride',
      'More',
      'Analytics',
      'Pending',
      'Assigned',
      'Billing',
    ]) {
      expect(
        find.text(forbidden),
        findsNothing,
        reason: 'driver must not see "$forbidden"',
      );
    }

    expect($('Sign In'), findsNothing);
  });
}
