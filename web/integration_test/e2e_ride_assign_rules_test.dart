@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Negative business-rule flows at assignment: blacklist enforcement and
/// schedule-conflict detection must reject the assignment AND leave the ride
/// Requested. Guards RideService.assignDriver (RideService.scala:440 blacklist,
/// :448/703 schedule conflict).
void main() {
  late String clientToken;
  late String dispatcherToken;

  setUp(() async {
    await resetTestData();
    clientToken = await apiLogin(kDevClient1, kDevPassword);
    dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
  });

  test('cannot assign a driver blacklisted for the ride client', () async {
    // Blacklist Hans for the BMW client.
    final bl = await addBlacklist(
        dispatcherToken, bmwClientId, hansDriverId, 'e2e blacklist');
    expect(bl.status, anyOf(200, 201), reason: 'blacklist entry should be created');

    final rideId = await createRideId(clientToken);
    final res = await assignDriver(rideId, dispatcherToken, driverId: hansDriverId);
    expect(res.status, 400,
        reason: 'assigning a blacklisted driver must be 400, was ${res.status}');
    expect(res.error?.toLowerCase(), contains('blacklist'),
        reason: 'error should mention the blacklist: ${res.error}');
    expect(await rideStatus(rideId, dispatcherToken), 'Requested',
        reason: 'the ride must remain Requested after the rejected assignment');
  });

  test('cannot assign one driver to two overlapping rides', () async {
    // Two rides at the same pickup time → within the 30-min buffer → conflict.
    final pickup = pickupAt(const Duration(hours: 3));
    final ride1 = await createRideId(clientToken, pickupDateTime: pickup);
    final ride2 = await createRideId(clientToken, pickupDateTime: pickup);

    final first = await assignDriver(ride1, dispatcherToken, driverId: hansDriverId);
    expect(first.status, anyOf(200, 201), reason: 'first assign should succeed');

    final second = await assignDriver(ride2, dispatcherToken, driverId: hansDriverId);
    expect(second.status, 400,
        reason: 'an overlapping assignment must be 400, was ${second.status}');
    expect(res2Lower(second.error), contains('buffer'),
        reason: 'error should explain the schedule conflict: ${second.error}');
    expect(await rideStatus(ride2, dispatcherToken), 'Requested',
        reason: 'the second ride must stay Requested after the conflict');
  });
}

String res2Lower(String? s) => (s ?? '').toLowerCase();
