import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'notif_helpers.dart';

/// Notification happy-path: assigning a driver to a ride must produce an in-app
/// notification for that driver. The backend's PushNotificationListener saves a
/// "New Ride Assigned" notification to the assigned driver on RideAssigned.
///
/// We seed + assign a ride via the API, then drive the driver's UI: open the
/// NotificationBell → the "Notifications" screen shows the entry. We also assert
/// the REST inbox/unread-count independently of UI flake.
void main() {
  patrolTest('driver receives in-app notification when assigned a ride', (
    $,
  ) async {
    await resetTestData();
    final rideId = await seedAssignedRide();

    // Backend-level assertion first: the driver has an unread "ride_assigned".
    final driverToken = await apiLogin(kDevDriver1, kDevPassword);
    final unread = await unreadCount(driverToken);
    expect(
      unread,
      greaterThanOrEqualTo(1),
      reason: 'driver should have >=1 unread notification after assignment',
    );
    final notifs = await fetchNotifications(driverToken);
    expect(
      notifs.any((n) => n['notificationType'] == 'ride_assigned'),
      isTrue,
      reason:
          'driver inbox should contain a ride_assigned notification for $rideId',
    );

    // UI-level assertion: the driver sees it in the Notifications screen.
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    await openNotifications($);

    expect($('New Ride Assigned'), findsWidgets);
  });
}
