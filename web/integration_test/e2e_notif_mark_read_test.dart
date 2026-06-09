import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'notif_helpers.dart';

/// Marking notifications as read: after the driver opens the Notifications
/// screen and taps "Mark all read", the unread count drops to zero. Exercises
/// PUT /api/notifications/read-all and the UI button.
void main() {
  patrolTest('driver marks all notifications read and unread count clears',
      ($) async {
    await resetTestData();
    await seedAssignedRide();

    final driverToken = await apiLogin(kDevDriver1, kDevPassword);
    expect(await unreadCount(driverToken), greaterThanOrEqualTo(1),
        reason: 'precondition: driver has at least one unread notification');

    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    await openNotifications($);
    expect($('New Ride Assigned'), findsWidgets);

    await $('Mark all read').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // Backend reflects the read state.
    expect(await unreadCount(driverToken), 0,
        reason: 'unread count should be 0 after "Mark all read"');
  });
}
