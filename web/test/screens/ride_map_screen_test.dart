// Tests for RideMapScreen — the ride-bound map for driver and dispatcher.
//
// The stateful screen itself mounts a Mapbox platform view, so (matching the
// ClientMapScreen tests) we cover the pure static logic plus the route()
// factory by building the route subtree WITHOUT mounting it.
//
// Mutation checks:
// - shouldApplyDriverLocation: flip the rideId comparison and the
//   filter tests go red.
// - route(): drop the RouteSettings name or stop passing the ride through and
//   the route test goes red.

import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/ride_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('RideMapScreen.shouldApplyDriverLocation', () {
    final ride = TestFixtures.ride(id: 'ride-1', driverId: 'driver-1');

    test('accepts an event carrying the tracked ride id', () {
      expect(
        RideMapScreen.shouldApplyDriverLocation(
          ride,
          eventRideId: 'ride-1',
          eventDriverId: null,
        ),
        isTrue,
      );
    });

    test('rejects an event for another ride even from the same driver', () {
      // Without this the map paints a ghost marker from the driver's OTHER
      // ride the moment they run two rides back to back.
      expect(
        RideMapScreen.shouldApplyDriverLocation(
          ride,
          eventRideId: 'ride-2',
          eventDriverId: 'driver-1',
        ),
        isFalse,
      );
    });

    test('falls back to the driver id when the event has no ride id', () {
      expect(
        RideMapScreen.shouldApplyDriverLocation(
          ride,
          eventRideId: null,
          eventDriverId: 'driver-1',
        ),
        isTrue,
      );
      expect(
        RideMapScreen.shouldApplyDriverLocation(
          ride,
          eventRideId: null,
          eventDriverId: 'driver-2',
        ),
        isFalse,
      );
    });

    test('rejects an anonymous event outright', () {
      expect(
        RideMapScreen.shouldApplyDriverLocation(
          ride,
          eventRideId: null,
          eventDriverId: null,
        ),
        isFalse,
      );
    });
  });

  group('RideMapScreen.isLiveTrackable', () {
    test('only rides with a driver actively on the road are trackable', () {
      Ride rideWith(RideStatus status, {String? driverId = 'driver-1'}) =>
          TestFixtures.ride(status: status, driverId: driverId);

      expect(
        RideMapScreen.isLiveTrackable(rideWith(RideStatus.assigned)),
        isTrue,
      );
      expect(
        RideMapScreen.isLiveTrackable(rideWith(RideStatus.confirmed)),
        isTrue,
      );
      expect(
        RideMapScreen.isLiveTrackable(rideWith(RideStatus.inProgress)),
        isTrue,
      );
      expect(
        RideMapScreen.isLiveTrackable(rideWith(RideStatus.requested)),
        isFalse,
      );
      expect(
        RideMapScreen.isLiveTrackable(rideWith(RideStatus.completed)),
        isFalse,
      );
      expect(
        RideMapScreen.isLiveTrackable(rideWith(RideStatus.cancelled)),
        isFalse,
      );
      expect(
        RideMapScreen.isLiveTrackable(
          rideWith(RideStatus.assigned, driverId: null),
        ),
        isFalse,
        reason: 'no driver — nothing to track',
      );
    });
  });

  testWidgets(
    'route() builds a named MaterialPageRoute carrying the same ride',
    (tester) async {
      final ride = TestFixtures.ride(id: 'ride-42');

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final route =
          RideMapScreen.route(capturedContext, ride: ride)
              as MaterialPageRoute<void>;

      // Named so tests (and analytics) can observe navigation to the map
      // without mounting the Mapbox platform view.
      expect(route.settings.name, RideMapScreen.routeName);

      // Build the route's subtree without mounting it (avoids spinning up the
      // Mapbox map / WebSocket).
      final built = route.builder(capturedContext);
      expect(built, isA<RideMapScreen>());
      expect((built as RideMapScreen).ride.id, 'ride-42');
    },
  );
}
