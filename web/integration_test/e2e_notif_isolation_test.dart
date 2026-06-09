@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'notif_helpers.dart';

/// In-app notifications are private to their recipient (filtered by personId in
/// NotificationRepository.findByPersonId). A notification addressed to the
/// assigned driver must NOT appear in another user's inbox.
///
/// Note: all V2 seed accounts share one company, so this asserts per-person
/// privacy rather than cross-company isolation. Cross-company isolation would
/// need a second company seeded via admin — tracked as a follow-up.
void main() {
  test('a driver notification is not visible to another client', () async {
    // Reset and seed: assigning Hans creates a "ride_assigned" for the driver.
    await resetTestData();
    // Clear the unrelated user's inbox so the isolation assertions are
    // independent of notifications accumulated by earlier runs.
    final otherToken = await apiLogin(kDevClient2, kDevPassword);
    await clearNotifications(otherToken);

    await seedAssignedRide();

    final driverToken = await apiLogin(kDevDriver1, kDevPassword);
    final driverNotifs = await fetchNotifications(driverToken);
    expect(
      driverNotifs.any((n) => n['notificationType'] == 'ride_assigned'),
      isTrue,
      reason: 'precondition: driver has the ride_assigned notification',
    );

    // A different user (Siemens client) must not see the driver's notification.
    final otherNotifs = await fetchNotifications(otherToken);
    expect(
      otherNotifs.any((n) => n['notificationType'] == 'ride_assigned'),
      isFalse,
      reason: "another user's inbox must not leak the driver's notification",
    );
    expect(await unreadCount(otherToken), 0,
        reason: 'the unrelated user should have no unread notifications');
  });
}
