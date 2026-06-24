import 'package:dispax/dashboard/dispatcher/utils/conflict_detector.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  final pickup = DateTime(2026, 6, 24, 10, 0);

  Ride rideAt(
    String id,
    DateTime at, {
    RideStatus status = RideStatus.assigned,
  }) {
    return TestFixtures.ride(id: id, pickupDateTime: at, status: status);
  }

  group('ConflictDetector.findConflicts', () {
    test(
      'does not report the ride being assigned as a conflict with itself',
      () {
        // The driver list already contains the very ride we are assigning
        // (re-assignment / it is already in rideState). It must not conflict
        // with itself even though its time window overlaps itself perfectly.
        final ride = rideAt('ride-1', pickup, status: RideStatus.requested);
        final driverRides = [
          rideAt('ride-1', pickup, status: RideStatus.assigned),
        ];

        expect(ConflictDetector.findConflicts(ride, driverRides), isEmpty);
      },
    );

    test('reports a different ride that overlaps the time window', () {
      final ride = rideAt('ride-1', pickup, status: RideStatus.requested);
      final driverRides = [
        // 30 min later — inside the 60-min overlap window.
        rideAt('ride-2', pickup.add(const Duration(minutes: 30))),
      ];

      final conflicts = ConflictDetector.findConflicts(ride, driverRides);

      expect(conflicts, hasLength(1));
      expect(conflicts.single.id, 'ride-2');
    });

    test('ignores a different ride outside the time window', () {
      final ride = rideAt('ride-1', pickup, status: RideStatus.requested);
      final driverRides = [
        // 90 min later — beyond the 60-min window.
        rideAt('ride-2', pickup.add(const Duration(minutes: 90))),
      ];

      expect(ConflictDetector.findConflicts(ride, driverRides), isEmpty);
    });

    test('ignores overlapping rides that are not in an active status', () {
      final ride = rideAt('ride-1', pickup, status: RideStatus.requested);
      // All overlap in time but none are assigned/confirmed/inProgress.
      final driverRides = [
        rideAt('ride-2', pickup, status: RideStatus.requested),
        rideAt('ride-3', pickup, status: RideStatus.cancelled),
        rideAt('ride-4', pickup, status: RideStatus.completed),
        rideAt('ride-5', pickup, status: RideStatus.handedOff),
      ];

      expect(ConflictDetector.findConflicts(ride, driverRides), isEmpty);
    });

    test('counts assigned, confirmed and inProgress as conflicts', () {
      final ride = rideAt('ride-1', pickup, status: RideStatus.requested);
      final driverRides = [
        rideAt('ride-2', pickup, status: RideStatus.assigned),
        rideAt('ride-3', pickup, status: RideStatus.confirmed),
        rideAt('ride-4', pickup, status: RideStatus.inProgress),
      ];

      final conflicts = ConflictDetector.findConflicts(ride, driverRides);

      expect(conflicts.map((r) => r.id), ['ride-2', 'ride-3', 'ride-4']);
    });
  });

  group('ConflictDetector.hasTimeConflict', () {
    test('is true when a different active ride overlaps', () {
      final ride = rideAt('ride-1', pickup, status: RideStatus.requested);
      final driverRides = [rideAt('ride-2', pickup)];

      expect(ConflictDetector.hasTimeConflict(ride, driverRides), isTrue);
    });

    test('is false when the only overlapping ride is the ride itself', () {
      final ride = rideAt('ride-1', pickup, status: RideStatus.requested);
      final driverRides = [
        rideAt('ride-1', pickup, status: RideStatus.assigned),
      ];

      expect(ConflictDetector.hasTimeConflict(ride, driverRides), isFalse);
    });
  });
}
