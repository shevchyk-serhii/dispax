@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Rating validation: out-of-range stars, an unfinished ride, and a double
/// rating must each return a client error (4xx), NOT a 500. Guards the rating
/// route in RideRoutes (validation now maps to typed RideError → 4xx).
void main() {
  late String clientToken;
  late String dispatcherToken;

  // Log in once to avoid tripping the /auth/login rate limiter across tests.
  setUpAll(() async {
    clientToken = await apiLogin(kDevClient1, kDevPassword);
    dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
  });

  setUp(() async {
    await resetTestData();
  });

  test('rejects a rating below 1 with a 4xx (not 500)', () async {
    final rideId = await completeRide(clientToken, dispatcherToken);
    final res = await rateRide(rideId, clientToken, 0);
    expect(res.status, 400, reason: 'rating 0 must be 400, was ${res.status}');
  });

  test('rejects a rating above 5 with a 4xx (not 500)', () async {
    final rideId = await completeRide(clientToken, dispatcherToken);
    final res = await rateRide(rideId, clientToken, 6);
    expect(res.status, 400, reason: 'rating 6 must be 400, was ${res.status}');
  });

  test('rejects rating a non-completed ride with a 4xx (not 500)', () async {
    final rideId = await createRideId(clientToken); // Requested
    final res = await rateRide(rideId, clientToken, 5);
    expect(res.status, anyOf(400, 403, 409),
        reason: 'rating a non-completed ride must be 4xx, was ${res.status}');
  });

  test('accepts a valid rating on a completed ride, and rejects a second one',
      () async {
    final rideId = await completeRide(clientToken, dispatcherToken);

    final first = await rateRide(rideId, clientToken, 5);
    expect(first.status, anyOf(200, 201), reason: 'first rating should succeed');

    final second = await rateRide(rideId, clientToken, 4);
    expect(second.status, anyOf(400, 409),
        reason: 'a second rating must be a 4xx, was ${second.status}');
  });
}
