import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// NEGATIVE (role access): a secretary cannot see dispatcher/driver navigation.
///
/// A secretary's dashboard exposes only Home / Rides / Create / Settings. The
/// dispatch board, More admin grid, analytics, billing, and driver-only Map /
/// Calendar must not be reachable.
void main() {
  patrolTest('secretary cannot see dispatcher or driver navigation', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevSecretary, kDevPassword);
    if (skipIfBackendDown($)) return;

    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    for (final forbidden in const [
      'New Ride',
      'More',
      'Schedule',
      'Analytics',
      'Pending',
      'Assigned',
      'Billing',
      'Map',
      'Calendar',
    ]) {
      expect(
        find.text(forbidden),
        findsNothing,
        reason: 'secretary must not see "$forbidden"',
      );
    }

    expect($('Sign In'), findsNothing);
  });
}
