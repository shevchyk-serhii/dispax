// Tests for ClientMapScreen.shouldApplyDriverLocation — the pure predicate that
// decides whether an incoming driver location update belongs to the ride being
// tracked.
//
// Regression: the screen used `_activeRide == null || driverId == ...`, so when
// the tracked ride cleared (_activeRide == null) ANY driver location event
// passed and painted a ghost marker. The predicate must require an active ride
// AND a matching driver id.

import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/client_map_screen.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('ClientMapScreen.shouldApplyDriverLocation', () {
    final tracked = TestFixtures.ride(
      id: 'r1',
      driverId: 'driver-1',
      status: RideStatus.inProgress,
    );

    test('no active ride → ignore the update (no ghost marker)', () {
      expect(
        ClientMapScreen.shouldApplyDriverLocation(
          null,
          eventDriverId: 'driver-1',
        ),
        isFalse,
      );
    });

    test('matching driver of the tracked ride → apply', () {
      expect(
        ClientMapScreen.shouldApplyDriverLocation(
          tracked,
          eventDriverId: 'driver-1',
        ),
        isTrue,
      );
    });

    test('different driver → ignore', () {
      expect(
        ClientMapScreen.shouldApplyDriverLocation(
          tracked,
          eventDriverId: 'driver-2',
        ),
        isFalse,
      );
    });

    test('null event driver id → ignore', () {
      expect(
        ClientMapScreen.shouldApplyDriverLocation(tracked, eventDriverId: null),
        isFalse,
      );
    });
  });

  group('ClientMapScreen.shouldResetApproaching', () {
    final rideA = TestFixtures.ride(id: 'A', driverId: 'd1');
    final rideB = TestFixtures.ride(id: 'B', driverId: 'd2');

    test('changing to a different ride re-arms the banner', () {
      expect(ClientMapScreen.shouldResetApproaching(rideA, rideB), isTrue);
    });

    test('starting to track a ride (from none) re-arms', () {
      expect(ClientMapScreen.shouldResetApproaching(null, rideA), isTrue);
    });

    test('same ride id → keep the latch (no spurious re-fire)', () {
      final sameIdUpdated = rideA.copyWith(status: RideStatus.inProgress);
      expect(
        ClientMapScreen.shouldResetApproaching(rideA, sameIdUpdated),
        isFalse,
      );
    });
  });
}
