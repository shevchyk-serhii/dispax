@Tags(['integration'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';
import 'notif_helpers.dart';

/// When the assigned driver nears the pickup, the client gets a "Driver
/// Approaching" notification. The proximity event (DriverApproaching) carries
/// the ride's clientId, and PushNotificationListener delivers it to the client.
///
/// We seed an assigned ride (pickup at Marienplatz), push the driver's location
/// to the same spot to cross the proximity thresholds, and assert the client
/// received a driver_approaching notification.
///
/// Marienplatz, München ≈ (48.1374, 11.5755).
const double _marienplatzLat = 48.1374;
const double _marienplatzLng = 11.5755;

Future<void> _pushDriverLocation(
  String driverId,
  double lat,
  double lng,
) async {
  final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
  await http.put(
    Uri.parse('$kApiBaseUrl/drivers/$driverId/location'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $dispatcherToken',
    },
    body: jsonEncode({'latitude': lat, 'longitude': lng}),
  );
}

void main() {
  test('client is notified when the driver is approaching the pickup', () async {
    await resetTestData();
    final clientToken = await apiLogin(kDevClient1, kDevPassword);
    await clearNotifications(clientToken);

    await seedAssignedRide(); // pickup at Marienplatz, driver = Hans

    // Move the driver onto the pickup point to cross the proximity thresholds.
    await _pushDriverLocation(hansDriverId, _marienplatzLat, _marienplatzLng);

    // The proximity event flows through the geofence service then the EventHub
    // listener asynchronously, so poll until it lands.
    final notifs = await waitForNotification(
      clientToken,
      (n) => n['notificationType'] == 'driver_approaching',
    );
    expect(
      notifs.any((n) => n['notificationType'] == 'driver_approaching'),
      isTrue,
      reason: 'client should get a driver_approaching notification',
    );
  });
}
