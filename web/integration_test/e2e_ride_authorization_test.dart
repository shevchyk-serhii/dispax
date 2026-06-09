@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Negative authorization flows: only the assigned driver may start their ride.
/// Guards the ownership check in RideService.startRide (RideService.scala:170).
void main() {
  test('a different driver cannot start a ride assigned to someone else',
      () async {
    await resetTestData();
    final clientToken = await apiLogin(kDevClient1, kDevPassword);
    final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
    final otherDriverToken = await apiLogin(kDevDriver2, kDevPassword);

    final rideId = await createRideId(clientToken);
    // Assign to Hans (driver1).
    final assign =
        await assignDriver(rideId, dispatcherToken, driverId: hansDriverId);
    expect(assign.status, anyOf(200, 201));

    // Klaus (driver2) tries to start Hans's ride.
    final res = await setStatus(rideId, otherDriverToken, 'InProgress');
    expect(res.status, 403,
        reason: 'a non-assigned driver must be forbidden, was ${res.status}');
    expect(await rideStatus(rideId, dispatcherToken), 'Assigned',
        reason: 'the ride must stay Assigned after the rejected start');
  });
}
