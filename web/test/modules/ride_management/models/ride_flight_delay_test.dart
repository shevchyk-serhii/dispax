// Unit tests for the flight-delay getters on Ride: flightDelayMinutes (latest known minus
// scheduled) and isFlightDelayed (positive delay OR an explicit "delayed" board status).

import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  group('Ride.flightDelayMinutes', () {
    test('is the difference between flightTime and flightScheduledTime', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightScheduledTime: DateTime(2026, 3, 15, 14, 0),
        flightTime: DateTime(2026, 3, 15, 14, 30),
      );
      expect(ride.flightDelayMinutes, 30);
    });

    test('is null when either time is missing', () {
      final noScheduled = TestFixtures.ride(
        isAirportTransfer: true,
        flightTime: DateTime(2026, 3, 15, 14, 30),
      );
      expect(noScheduled.flightDelayMinutes, isNull);
    });

    test('is zero for an on-time flight', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightScheduledTime: DateTime(2026, 3, 15, 14, 0),
        flightTime: DateTime(2026, 3, 15, 14, 0),
      );
      expect(ride.flightDelayMinutes, 0);
    });
  });

  group('Ride.isFlightDelayed', () {
    test('true when the computed delay is positive', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightScheduledTime: DateTime(2026, 3, 15, 14, 0),
        flightTime: DateTime(2026, 3, 15, 14, 20),
      );
      expect(ride.isFlightDelayed, isTrue);
    });

    test('true when the board status is "delayed" even without two times', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightStatus: 'delayed',
      );
      expect(ride.isFlightDelayed, isTrue);
    });

    test('false for an on-time flight', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightScheduledTime: DateTime(2026, 3, 15, 14, 0),
        flightTime: DateTime(2026, 3, 15, 14, 0),
        flightStatus: 'landed',
      );
      expect(ride.isFlightDelayed, isFalse);
    });
  });
}
