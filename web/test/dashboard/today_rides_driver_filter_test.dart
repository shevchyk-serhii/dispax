import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('ridesDrivenBy', () {
    test('keeps only rides assigned to the given driver', () {
      final rides = [
        TestFixtures.ride(id: 'mine-1', driverId: 'me'),
        TestFixtures.ride(id: 'other-1', driverId: 'someone-else'),
        TestFixtures.ride(id: 'mine-2', driverId: 'me'),
      ];

      final result = ridesDrivenBy(rides, 'me');

      expect(result.map((r) => r.id), ['mine-1', 'mine-2']);
    });

    test('drops unassigned rides (driverId == null)', () {
      final rides = [
        TestFixtures.ride(id: 'mine', driverId: 'me'),
        TestFixtures.ride(id: 'unassigned'), // driverId defaults to null
      ];

      final result = ridesDrivenBy(rides, 'me');

      expect(result.map((r) => r.id), ['mine']);
    });

    test('returns empty when none of the rides belong to the driver', () {
      final rides = [
        TestFixtures.ride(id: 'a', driverId: 'driver-a'),
        TestFixtures.ride(id: 'b', driverId: 'driver-b'),
      ];

      expect(ridesDrivenBy(rides, 'me'), isEmpty);
    });

    test('returns empty for an empty input list', () {
      expect(ridesDrivenBy(const <Ride>[], 'me'), isEmpty);
    });
  });
}
