// Regression guard: a ride must land in exactly ONE of the driver's Today /
// Upcoming tabs, never both.
//
// Before the fix, getTodayRides used the window [today 00:00, tomorrow 00:00)
// while getUpcomingRides used a bare `isAfter(now)`. A ride scheduled later
// *today* (e.g. now 14:30, pickup 22:00) satisfied both predicates and rendered
// in both tabs. The two filters now share an exact day boundary: Today owns the
// current calendar day; Upcoming starts at tomorrow 00:00.

import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  // A fixed "now" so the day boundary is deterministic: mid-afternoon today.
  final now = DateTime(2026, 3, 15, 14, 30);

  Ride at(
    String id,
    DateTime pickup, {
    RideStatus status = RideStatus.assigned,
  }) => TestFixtures.ride(id: id, pickupDateTime: pickup, status: status);

  group('today/upcoming split — no duplicate render', () {
    test('a ride later today is in Today only, not Upcoming', () {
      final laterToday = at('evening', DateTime(2026, 3, 15, 22, 0));

      final today = todayRidesFilter([laterToday], now).map((r) => r.id);
      final upcoming = upcomingRidesFilter([laterToday], now).map((r) => r.id);

      expect(today, contains('evening'));
      expect(upcoming, isNot(contains('evening')));
    });

    test('a ride tomorrow is in Upcoming only, not Today', () {
      final tomorrow = at('tmrw', DateTime(2026, 3, 16, 9, 0));

      final today = todayRidesFilter([tomorrow], now).map((r) => r.id);
      final upcoming = upcomingRidesFilter([tomorrow], now).map((r) => r.id);

      expect(today, isNot(contains('tmrw')));
      expect(upcoming, contains('tmrw'));
    });

    test('no ride appears in both lists for a mixed set', () {
      final rides = [
        at('past', DateTime(2026, 3, 15, 8, 0)), // earlier today
        at('evening', DateTime(2026, 3, 15, 22, 0)), // later today
        at('tomorrow', DateTime(2026, 3, 16, 9, 0)),
        at('next-week', DateTime(2026, 3, 22, 9, 0)),
      ];

      final today = todayRidesFilter(rides, now).map((r) => r.id).toSet();
      final upcoming = upcomingRidesFilter(rides, now).map((r) => r.id).toSet();

      expect(
        today.intersection(upcoming),
        isEmpty,
        reason: 'a ride must not be in both Today and Upcoming',
      );
    });
  });

  group('day boundaries', () {
    test('midnight today belongs to Today, not Upcoming', () {
      final midnight = at('midnight', DateTime(2026, 3, 15, 0, 0));

      expect(
        todayRidesFilter([midnight], now).map((r) => r.id),
        contains('midnight'),
      );
      expect(
        upcomingRidesFilter([midnight], now).map((r) => r.id),
        isNot(contains('midnight')),
      );
    });

    test('tomorrow midnight belongs to Upcoming, not Today', () {
      final tmrwMidnight = at('tmrw-midnight', DateTime(2026, 3, 16, 0, 0));

      expect(
        todayRidesFilter([tmrwMidnight], now).map((r) => r.id),
        isNot(contains('tmrw-midnight')),
      );
      expect(
        upcomingRidesFilter([tmrwMidnight], now).map((r) => r.id),
        contains('tmrw-midnight'),
      );
    });
  });

  group('status filtering', () {
    test('Today drops completed/cancelled rides', () {
      final rides = [
        at('done', DateTime(2026, 3, 15, 12, 0), status: RideStatus.completed),
        at('gone', DateTime(2026, 3, 15, 12, 0), status: RideStatus.cancelled),
        at('live', DateTime(2026, 3, 15, 12, 0), status: RideStatus.inProgress),
      ];

      expect(todayRidesFilter(rides, now).map((r) => r.id), ['live']);
    });

    test('Upcoming keeps only requested/assigned/confirmed', () {
      final rides = [
        at('req', DateTime(2026, 3, 16, 9, 0), status: RideStatus.requested),
        at('asg', DateTime(2026, 3, 16, 9, 0), status: RideStatus.assigned),
        at('cfm', DateTime(2026, 3, 16, 9, 0), status: RideStatus.confirmed),
        at('prog', DateTime(2026, 3, 16, 9, 0), status: RideStatus.inProgress),
        at('done', DateTime(2026, 3, 16, 9, 0), status: RideStatus.completed),
      ];

      expect(upcomingRidesFilter(rides, now).map((r) => r.id).toSet(), {
        'req',
        'asg',
        'cfm',
      });
    });
  });
}
