import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Negative: a client must not see dispatcher/admin navigation. Their bottom
/// nav is Home/Rides/Book/Map/Settings only — no New Ride, More, Schedule,
/// Analytics, Pending or Assigned tabs. Confirms role isolation in the UI.
void main() {
  patrolTest('client cannot see dispatcher or admin navigation', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Client tabs are present.
    for (final tab in ['Home', 'Rides', 'Book', 'Map', 'Settings']) {
      expect(find.text(tab), findsWidgets, reason: 'client tab "$tab" missing');
    }

    // Dispatcher/admin-only destinations must be absent.
    for (final forbidden in [
      'New Ride',
      'More',
      'Schedule',
      'Analytics',
      'Pending',
      'Assigned',
    ]) {
      expect(
        find.text(forbidden),
        findsNothing,
        reason: 'client must not see "$forbidden"',
      );
    }
  });
}
