@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Negative state-machine flows: the backend must reject illegal transitions
/// AND leave the ride in its prior state. These guard RideService's canBeXxx
/// predicates against regressions (RideService.scala:198/214/217/423).
void main() {
  late String clientToken;
  late String dispatcherToken;

  setUp(() async {
    await resetTestData();
    clientToken = await apiLogin(kDevClient1, kDevPassword);
    dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
  });

  test('cannot complete a ride that was never started', () async {
    final rideId = await createRideId(clientToken);

    final res = await setStatus(rideId, dispatcherToken, 'Completed');
    expect(
      res.status,
      409,
      reason: 'Requested→Completed must be a 409 conflict, was ${res.status}',
    );
    expect(
      await rideStatus(rideId, dispatcherToken),
      'Requested',
      reason: 'the ride must stay Requested after a rejected completion',
    );
  });

  test('cannot assign a driver to an already-assigned ride', () async {
    final rideId = await createRideId(clientToken);
    final first = await assignDriver(
      rideId,
      dispatcherToken,
      driverId: hansDriverId,
    );
    expect(
      first.status,
      anyOf(200, 201),
      reason: 'first assign should succeed',
    );

    final second = await assignDriver(
      rideId,
      dispatcherToken,
      driverId: klausDriverId,
    );
    expect(
      second.status,
      409,
      reason: 'assigning an Assigned ride must be a 409, was ${second.status}',
    );
    expect(
      await rideStatus(rideId, dispatcherToken),
      'Assigned',
      reason: 'the ride must remain Assigned (to the first driver)',
    );
  });

  test('cannot cancel a completed ride', () async {
    final rideId = await createRideId(clientToken);
    await assignDriver(rideId, dispatcherToken, driverId: hansDriverId);
    await setStatus(rideId, dispatcherToken, 'InProgress');
    await setStatus(rideId, dispatcherToken, 'Completed');

    final res = await cancelRide(rideId, dispatcherToken);
    expect(
      res.status,
      403,
      reason: 'cancelling a Completed ride must be 403, was ${res.status}',
    );
    expect(
      await rideStatus(rideId, dispatcherToken),
      'Completed',
      reason: 'the ride must stay Completed after a rejected cancellation',
    );
  });
}
