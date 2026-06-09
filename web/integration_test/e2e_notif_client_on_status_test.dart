@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'notif_helpers.dart';

/// The client who booked a ride is notified when it is assigned ("Driver
/// Assigned") and when it starts ("Ride Started"). PushNotificationListener
/// saves these to the client in addition to the driver.
void main() {
  test('client is notified when their ride is assigned and started', () async {
    await resetTestData();
    final clientToken = await apiLogin(kDevClient1, kDevPassword);
    await clearNotifications(clientToken);
    final rideId = await seedRequestedRide(token: clientToken);
    await assignDriver(rideId);
    await setStatus(rideId, 'InProgress');

    final notifs = await fetchNotifications(clientToken);
    final titles = notifs.map((n) => n['title']).toList();
    expect(titles, contains('Driver Assigned'),
        reason: 'client should be told a driver was assigned');
    expect(titles, contains('Ride Started'),
        reason: 'client should be told the ride started');
  });
}
