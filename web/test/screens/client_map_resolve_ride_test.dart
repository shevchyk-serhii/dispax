import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/client_map_screen.dart';

import '../helpers/test_fixtures.dart';

// Tests for ClientMapScreen.resolveRide — the pure ride-selection logic that
// decides which ride to display on the map.
//
// Mutation check performed:
//   - Temporarily replaced `r.isTrackable` with `false` in resolveRide:
//     every test that expects a non-null result turned red.
//   - Temporarily replaced `r.clientId == userId` with `true`:
//     the "another client's ride → null" test turned red.
//   Restored the correct implementation after each mutation.

void main() {
  group('ClientMapScreen.resolveRide', () {
    const ownerId = 'client-SELF';
    const otherId = 'client-OTHER';

    Ride ownedRide(String id, RideStatus status) =>
        TestFixtures.ride(id: id, clientId: ownerId, status: status);

    Ride otherRide(String id, RideStatus status) =>
        TestFixtures.ride(id: id, clientId: otherId, status: status);

    // ── No rideId (fallback to first trackable) ─────────────────────────────

    test('null userId → null regardless of rides', () {
      final rides = [ownedRide('r1', RideStatus.assigned)];
      expect(
        ClientMapScreen.resolveRide(rides, userId: null, rideId: null),
        isNull,
      );
    });

    test('no rides → null', () {
      expect(
        ClientMapScreen.resolveRide([], userId: ownerId, rideId: null),
        isNull,
      );
    });

    test('no trackable ride owned by user → null', () {
      final rides = [
        ownedRide('r1', RideStatus.requested),
        ownedRide('r2', RideStatus.completed),
        ownedRide('r3', RideStatus.cancelled),
      ];
      expect(
        ClientMapScreen.resolveRide(rides, userId: ownerId, rideId: null),
        isNull,
      );
    });

    test('returns first trackable ride when no rideId given', () {
      final rides = [
        ownedRide('r-assigned', RideStatus.assigned),
        ownedRide('r-inprogress', RideStatus.inProgress),
      ];
      final result = ClientMapScreen.resolveRide(
        rides,
        userId: ownerId,
        rideId: null,
      );
      expect(result, isNotNull);
      expect(result!.id, 'r-assigned'); // first in list
    });

    test('ignores rides from another client when no rideId given', () {
      final rides = [
        otherRide('r-other', RideStatus.assigned),
        ownedRide('r-own', RideStatus.inProgress),
      ];
      final result = ClientMapScreen.resolveRide(
        rides,
        userId: ownerId,
        rideId: null,
      );
      expect(result?.id, 'r-own');
    });

    // ── With rideId (exact match) ─────────────────────────────────────────

    test('rideId + trackable owned ride → returns that ride', () {
      final rides = [
        ownedRide('r-want', RideStatus.inProgress),
        ownedRide('r-other', RideStatus.assigned),
      ];
      final result = ClientMapScreen.resolveRide(
        rides,
        userId: ownerId,
        rideId: 'r-want',
      );
      expect(result?.id, 'r-want');
      expect(result?.status, RideStatus.inProgress);
    });

    // Security guard: a client must not be able to view another client's ride
    // by passing that client's rideId.
    test('rideId belonging to another client → null (tenant guard)', () {
      final rides = [
        otherRide('r-foreign', RideStatus.assigned),
        ownedRide('r-own', RideStatus.inProgress),
      ];
      expect(
        ClientMapScreen.resolveRide(
          rides,
          userId: ownerId,
          rideId: 'r-foreign',
        ),
        isNull,
      );
    });

    test('rideId with non-trackable status → null', () {
      final rides = [
        ownedRide('r-done', RideStatus.completed),
        ownedRide('r-active', RideStatus.assigned),
      ];
      expect(
        ClientMapScreen.resolveRide(rides, userId: ownerId, rideId: 'r-done'),
        isNull,
      );
    });

    test('rideId that does not exist in the list → null', () {
      final rides = [ownedRide('r-known', RideStatus.assigned)];
      expect(
        ClientMapScreen.resolveRide(
          rides,
          userId: ownerId,
          rideId: 'r-unknown',
        ),
        isNull,
      );
    });

    // ── All trackable statuses are accepted ────────────────────────────────

    for (final status in [
      RideStatus.assigned,
      RideStatus.confirmed,
      RideStatus.inProgress,
      RideStatus.handedOff,
    ]) {
      test('$status is accepted as trackable with rideId', () {
        final rides = [ownedRide('r-test', status)];
        final result = ClientMapScreen.resolveRide(
          rides,
          userId: ownerId,
          rideId: 'r-test',
        );
        expect(result?.id, 'r-test');
      });
    }

    // ── Non-trackable statuses are rejected ────────────────────────────────

    for (final status in [
      RideStatus.requested,
      RideStatus.completed,
      RideStatus.cancelled,
    ]) {
      test('$status is rejected as non-trackable with rideId', () {
        final rides = [ownedRide('r-test', status)];
        expect(
          ClientMapScreen.resolveRide(rides, userId: ownerId, rideId: 'r-test'),
          isNull,
        );
      });
    }

    // ── Without rideId: non-trackable statuses are skipped ─────────────────

    for (final status in [
      RideStatus.requested,
      RideStatus.completed,
      RideStatus.cancelled,
    ]) {
      test('$status is skipped without rideId (no fallback match)', () {
        final rides = [ownedRide('r-test', status)];
        expect(
          ClientMapScreen.resolveRide(rides, userId: ownerId, rideId: null),
          isNull,
        );
      });
    }
  });
}
