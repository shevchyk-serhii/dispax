// Regression tests for RideMapScreen.decideRideEvent — the pure decision that
// maps a lifecycle WebSocket event onto the tracked ride.
//
// The bug: RideMapScreen froze the ride at push time and listened only to
// LocationUpdated/RideStatusChanged. After a driver reassignment the stale
// driverId kept matching the OLD driver, so the marker (with the old driver's
// name) froze on the old driver forever; RideConfirmed/RideRejected (separate
// event types, not RideStatusChanged) never updated the status pill.
//
// Mutation check: revert the fix (the helper and its wiring) and this file
// fails — the decision logic does not exist on the unfixed screen.

import 'package:dispax/modules/core/models/websocket_event.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/ride_map_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

WebSocketEvent _event(
  String type, {
  String? rideId,
  String? driverId,
  String? newStatus,
}) {
  return WebSocketEvent(
    type: type,
    rideId: rideId,
    driverId: driverId,
    newStatus: newStatus,
    companyId: 'company-1',
  );
}

void main() {
  final ride = TestFixtures.ride(
    id: 'ride-1',
    driverId: 'driver-1',
    driverName: 'Old Driver',
    status: RideStatus.assigned,
  );

  group('RideMapScreen.decideRideEvent — driver reassignment', () {
    test('RideAssigned with a NEW driver flags the driver change', () {
      final decision = RideMapScreen.decideRideEvent(
        ride,
        _event('RideAssigned', rideId: 'ride-1', driverId: 'driver-2'),
      );

      expect(decision, isNotNull);
      expect(
        decision!.driverChanged,
        isTrue,
        reason:
            'A reassignment must be detected or the map keeps tracking the '
            'old driver with his name on the marker',
      );
      expect(decision.driverId, 'driver-2');
    });

    test('RideAssigned for another ride is ignored', () {
      final decision = RideMapScreen.decideRideEvent(
        ride,
        _event('RideAssigned', rideId: 'ride-2', driverId: 'driver-2'),
      );
      expect(decision, isNull);
    });

    test('RideAssigned with the same driver and status is a no-op', () {
      final decision = RideMapScreen.decideRideEvent(
        ride,
        _event('RideAssigned', rideId: 'ride-1', driverId: 'driver-1'),
      );
      expect(decision, isNull);
    });

    test('RideAssigned on a requested ride also updates the status pill', () {
      final requested = TestFixtures.ride(
        id: 'ride-1',
        status: RideStatus.requested,
      );
      final decision = RideMapScreen.decideRideEvent(
        requested,
        _event('RideAssigned', rideId: 'ride-1', driverId: 'driver-2'),
      );

      expect(decision, isNotNull);
      expect(decision!.status, RideStatus.assigned);
      expect(decision.driverChanged, isTrue);
      expect(decision.driverId, 'driver-2');
    });

    test('RideDetailsUpdated with a different driver flags the change', () {
      final decision = RideMapScreen.decideRideEvent(
        ride,
        _event('RideDetailsUpdated', rideId: 'ride-1', driverId: 'driver-2'),
      );

      expect(decision, isNotNull);
      expect(decision!.driverChanged, isTrue);
      expect(decision.driverId, 'driver-2');
      expect(decision.status, isNull, reason: 'details carry no status');
    });

    test('RideDetailsUpdated that unassigns the driver clears it', () {
      final decision = RideMapScreen.decideRideEvent(
        ride,
        _event('RideDetailsUpdated', rideId: 'ride-1', driverId: null),
      );

      expect(decision, isNotNull);
      expect(decision!.driverChanged, isTrue);
      expect(decision.driverId, isNull);
    });

    test('RideDetailsUpdated with the unchanged driver is a no-op', () {
      final decision = RideMapScreen.decideRideEvent(
        ride,
        _event('RideDetailsUpdated', rideId: 'ride-1', driverId: 'driver-1'),
      );
      expect(decision, isNull);
    });
  });

  group('RideMapScreen.decideRideEvent — confirm / reject pill', () {
    test('RideConfirmed flips the pill to confirmed', () {
      final decision = RideMapScreen.decideRideEvent(
        ride,
        _event('RideConfirmed', rideId: 'ride-1', driverId: 'driver-1'),
      );

      expect(decision, isNotNull);
      expect(
        decision!.status,
        RideStatus.confirmed,
        reason:
            'RideConfirmed is NOT a RideStatusChanged event — the pill must '
            'still follow it',
      );
      expect(decision.driverChanged, isFalse);
    });

    test('RideConfirmed on an already confirmed ride is a no-op', () {
      final confirmed = TestFixtures.ride(
        id: 'ride-1',
        driverId: 'driver-1',
        status: RideStatus.confirmed,
      );
      final decision = RideMapScreen.decideRideEvent(
        confirmed,
        _event('RideConfirmed', rideId: 'ride-1', driverId: 'driver-1'),
      );
      expect(decision, isNull);
    });

    test(
      'RideRejected reverts the pill to requested and unassigns the driver',
      () {
        final decision = RideMapScreen.decideRideEvent(
          ride,
          _event('RideRejected', rideId: 'ride-1', driverId: 'driver-1'),
        );

        expect(decision, isNotNull);
        expect(decision!.status, RideStatus.requested);
        expect(
          decision.driverChanged,
          isTrue,
          reason: 'the backend unassigns the driver on rejection',
        );
        expect(decision.driverId, isNull);
      },
    );

    test('RideConfirmed for another ride is ignored', () {
      final decision = RideMapScreen.decideRideEvent(
        ride,
        _event('RideConfirmed', rideId: 'ride-2', driverId: 'driver-1'),
      );
      expect(decision, isNull);
    });
  });

  group('RideMapScreen.decideRideEvent — RideStatusChanged (pre-existing)', () {
    test('a status change on the tracked ride updates the pill', () {
      final decision = RideMapScreen.decideRideEvent(
        ride,
        _event('RideStatusChanged', rideId: 'ride-1', newStatus: 'InProgress'),
      );

      expect(decision, isNotNull);
      expect(decision!.status, RideStatus.inProgress);
      expect(decision.driverChanged, isFalse);
    });

    test('an unparseable or identical status is a no-op', () {
      expect(
        RideMapScreen.decideRideEvent(
          ride,
          _event('RideStatusChanged', rideId: 'ride-1', newStatus: 'Garbage'),
        ),
        isNull,
      );
      expect(
        RideMapScreen.decideRideEvent(
          ride,
          _event('RideStatusChanged', rideId: 'ride-1', newStatus: 'Assigned'),
        ),
        isNull,
      );
    });

    test('unrelated event types are ignored', () {
      expect(
        RideMapScreen.decideRideEvent(
          ride,
          _event('ChatMessageSent', rideId: 'ride-1'),
        ),
        isNull,
      );
    });
  });

  group('Ride.copyWith driver fields', () {
    // The screen clears the stale driver name/location via copyWith when the
    // driver changes; without sentinel semantics `?? this.x` made an explicit
    // null a silent keep, so the OLD driver's name stayed on the marker.
    test('explicit null clears driverId, driverName and driverLocation', () {
      final withDriver = TestFixtures.ride(
        id: 'ride-1',
        driverId: 'driver-1',
        driverName: 'Old Driver',
      );
      final cleared = withDriver.copyWith(
        driverId: null,
        driverName: null,
        driverLocation: null,
      );

      expect(cleared.driverId, isNull);
      expect(cleared.driverName, isNull);
      expect(cleared.driverLocation, isNull);
    });

    test('omitting the driver fields keeps them', () {
      final withDriver = TestFixtures.ride(
        id: 'ride-1',
        driverId: 'driver-1',
        driverName: 'Old Driver',
      );
      final copied = withDriver.copyWith(status: RideStatus.confirmed);

      expect(copied.driverId, 'driver-1');
      expect(copied.driverName, 'Old Driver');
    });
  });
}
