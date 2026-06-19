import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'notif_helpers.dart';

/// The assigned driver must receive in-app notifications as their ride moves
/// through InProgress and Completed. PushNotificationListener saves "Ride
/// Started" and "Ride Completed" to the assigned driver on RideStatusChanged.
void main() {
  patrolTest('driver receives notifications on ride start and completion', (
    $,
  ) async {
    await resetTestData();
    final rideId = await seedAssignedRide();
    await setStatus(rideId, 'InProgress');
    await setStatus(rideId, 'Completed');

    // Backend-level assertion: both status notifications landed for the driver.
    final driverToken = await apiLogin(kDevDriver1, kDevPassword);
    final notifs = await fetchNotifications(driverToken);
    final titles = notifs.map((n) => n['title']).toList();
    expect(
      titles,
      contains('Ride Started'),
      reason: 'driver inbox should contain a "Ride Started" notification',
    );
    expect(
      titles,
      contains('Ride Completed'),
      reason: 'driver inbox should contain a "Ride Completed" notification',
    );

    // UI-level assertion: the completion notification is visible.
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    await openNotifications($);

    expect($('Ride Completed'), findsWidgets);
  });
}
