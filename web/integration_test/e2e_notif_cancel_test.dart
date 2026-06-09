@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'notif_helpers.dart';

/// Cancelling an assigned ride notifies the affected driver (and the client).
/// PushNotificationListener saves a "Ride Cancelled" notification on the
/// Cancelled status transition.
void main() {
  test('the assigned driver is notified when the ride is cancelled', () async {
    await resetTestData();
    final driverToken = await apiLogin(kDevDriver1, kDevPassword);
    // Start from a clean inbox so the assertion is independent of prior runs
    // (POST /api/dev/reset clears rides but not the notifications table).
    await clearNotifications(driverToken);

    final rideId = await seedAssignedRide();
    await cancelRide(rideId);

    final notifs = await fetchNotifications(driverToken);
    expect(
      notifs.any((n) => n['title'] == 'Ride Cancelled'),
      isTrue,
      reason: 'driver inbox should contain a "Ride Cancelled" notification',
    );
  });
}
