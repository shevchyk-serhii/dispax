// Regression: the Week/Month history filters used `isAfter(start)`, where
// start is the midnight beginning the week/month. A ride exactly at Monday
// 00:00:00 (or the 1st at 00:00:00) gave isAfter == false and silently
// vanished from the history. The window must be boundary-inclusive
// (`!isBefore(start)`).

import 'package:flutter_test/flutter_test.dart';

import 'package:dispax/dashboard/driver/ride_history_screen.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';

import '../../helpers/test_fixtures.dart';

void main() {
  const driverId = 'driver-1';

  Ride completedAt(DateTime pickup, {String id = 'r1'}) => TestFixtures.ride(
    id: id,
    status: RideStatus.completed,
    pickupDateTime: pickup,
    driverId: driverId,
  );

  group('completedRidesFor period boundaries', () {
    // Wednesday 2026-07-08 12:00; the week starts Monday 2026-07-06 00:00:00.
    final now = DateTime(2026, 7, 8, 12);

    test('week filter keeps a ride exactly at Monday midnight', () {
      final boundaryRide = completedAt(DateTime(2026, 7, 6));

      final result = completedRidesFor(
        [boundaryRide],
        driverId,
        RideHistoryPeriod.week,
        now,
      );

      expect(result, [boundaryRide]);
    });

    test('week filter still drops a ride before the week start', () {
      final lastWeek = completedAt(
        DateTime(2026, 7, 5, 23, 59, 59),
        id: 'r-old',
      );

      final result = completedRidesFor(
        [lastWeek],
        driverId,
        RideHistoryPeriod.week,
        now,
      );

      expect(result, isEmpty);
    });

    test('month filter keeps a ride exactly at the 1st midnight', () {
      final boundaryRide = completedAt(DateTime(2026, 7, 1));

      final result = completedRidesFor(
        [boundaryRide],
        driverId,
        RideHistoryPeriod.month,
        DateTime(2026, 7, 15, 9),
      );

      expect(result, [boundaryRide]);
    });

    test('month filter still drops a ride from the previous month', () {
      final june = completedAt(DateTime(2026, 6, 30, 23, 59, 59), id: 'r-jun');

      final result = completedRidesFor(
        [june],
        driverId,
        RideHistoryPeriod.month,
        DateTime(2026, 7, 15, 9),
      );

      expect(result, isEmpty);
    });
  });
}
