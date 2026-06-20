import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/dashboard/secretary/secretary_front_desk_stats.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('SecretaryFrontDeskStats', () {
    final day = DateTime(2026, 6, 20, 0, 0);

    Ride at(DateTime when, {RideStatus status = RideStatus.requested}) =>
        TestFixtures.ride(
          id: 'r-${when.microsecondsSinceEpoch}',
          pickupDateTime: when,
          status: status,
        );

    test('ridesOn keeps only rides whose pickup is on the given day', () {
      final rides = [
        at(DateTime(2026, 6, 20, 9)), // today
        at(DateTime(2026, 6, 20, 18)), // today
        at(DateTime(2026, 6, 19, 23)), // yesterday
        at(DateTime(2026, 6, 21, 1)), // tomorrow
      ];
      final result = SecretaryFrontDeskStats.ridesOn(rides, day: day);
      expect(result.length, 2);
    });

    test('bookedCount counts all rides on the day', () {
      final rides = [
        at(DateTime(2026, 6, 20, 9)),
        at(DateTime(2026, 6, 20, 12)),
        at(DateTime(2026, 6, 18, 9)),
      ];
      expect(SecretaryFrontDeskStats.bookedCount(rides, day: day), 2);
    });

    test('awaitingConfirmCount counts only Requested rides on the day', () {
      final rides = [
        at(DateTime(2026, 6, 20, 9), status: RideStatus.requested),
        at(DateTime(2026, 6, 20, 10), status: RideStatus.assigned),
        at(DateTime(2026, 6, 20, 11), status: RideStatus.requested),
        at(DateTime(2026, 6, 19, 9), status: RideStatus.requested), // other day
      ];
      expect(SecretaryFrontDeskStats.awaitingConfirmCount(rides, day: day), 2);
    });

    test('empty ride list yields zero counts', () {
      expect(SecretaryFrontDeskStats.bookedCount(const [], day: day), 0);
      expect(
        SecretaryFrontDeskStats.awaitingConfirmCount(const [], day: day),
        0,
      );
    });
  });
}
