@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'notif_helpers.dart';

/// When a client creates a ride, they receive an in-app booking confirmation.
/// PushNotificationListener saves a "Ride Booked" (ride_created) notification to
/// the client on RideCreated.
void main() {
  test(
    'client receives an in-app confirmation when they create a ride',
    () async {
      await resetTestData();
      final clientToken = await apiLogin(kDevClient1, kDevPassword);
      await clearNotifications(clientToken);
      final rideId = await seedRequestedRide(token: clientToken);

      final notifs = await fetchNotifications(clientToken);
      expect(
        notifs.any((n) => n['notificationType'] == 'ride_created'),
        isTrue,
        reason:
            'client inbox should contain a booking confirmation for ride $rideId',
      );
    },
  );
}
