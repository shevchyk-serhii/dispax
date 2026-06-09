@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Payment rules: a ride can only be marked paid once it is Completed, and
/// re-paying is idempotent (it must not overwrite paidAt). Guards
/// RideService.markPayment (RideService.scala:600).
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

  test('cannot mark a non-completed ride as paid', () async {
    final rideId = await createRideId(clientToken); // status Requested
    final res = await markPaid(rideId, dispatcherToken);
    expect(res.status, 400,
        reason: 'paying a Requested ride must be 400, was ${res.status}');
    final ride = await rideJson(rideId, dispatcherToken);
    expect(ride['paymentStatus'], 'Unpaid',
        reason: 'paymentStatus must stay Unpaid after the rejected payment');
  });

  test('marks a completed ride paid, and re-paying is idempotent', () async {
    final rideId = await completeRide(clientToken, dispatcherToken);

    final first = await markPaid(rideId, dispatcherToken);
    expect(first.status, anyOf(200, 201),
        reason: 'paying a Completed ride should succeed');
    final paidAt1 = (await rideJson(rideId, dispatcherToken))['paidAt'];
    expect(paidAt1, isNotNull, reason: 'paidAt should be set');

    await Future.delayed(const Duration(milliseconds: 1100));
    final second = await markPaid(rideId, dispatcherToken);
    expect(second.status, anyOf(200, 201));
    final paidAt2 = (await rideJson(rideId, dispatcherToken))['paidAt'];
    expect(paidAt2, paidAt1,
        reason: 're-paying must not overwrite paidAt (idempotent)');
  });
}
