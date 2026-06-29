// Unit tests for Ride.flightProgressFraction — the [0,1] position of the aircraft between take-off
// (flightDepartureTime) and the live landing (flightTime) that drives the en-route airplane icon.

import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  // A 2-hour window: departs 12:00, arrives 14:00.
  final dep = DateTime(2026, 3, 15, 12, 0);
  final arr = DateTime(2026, 3, 15, 14, 0);

  group('Ride.flightProgressFraction', () {
    test('is ~0.5 at the midpoint of the take-off → landing window', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightDepartureTime: dep,
        flightTime: arr,
      );
      expect(
        ride.flightProgressFraction(DateTime(2026, 3, 15, 13, 0)),
        closeTo(0.5, 0.001),
      );
    });

    test('clamps to 0 before take-off and 1 after landing', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightDepartureTime: dep,
        flightTime: arr,
      );
      expect(ride.flightProgressFraction(DateTime(2026, 3, 15, 11, 0)), 0.0);
      expect(ride.flightProgressFraction(DateTime(2026, 3, 15, 15, 0)), 1.0);
    });

    test(
      'a delayed landing (later flightTime) stretches the window, slowing the plane',
      () {
        final onTime = TestFixtures.ride(
          isAirportTransfer: true,
          isArrival: true,
          flightDepartureTime: dep,
          flightTime: arr, // 14:00
        );
        final delayed = TestFixtures.ride(
          isAirportTransfer: true,
          isArrival: true,
          flightDepartureTime: dep,
          flightTime: DateTime(2026, 3, 15, 15, 0), // +1h later landing
        );
        final at13 = DateTime(2026, 3, 15, 13, 0);
        // Same wall-clock instant → the delayed flight is LESS far along (denominator is larger).
        expect(
          delayed.flightProgressFraction(at13)! <
              onTime.flightProgressFraction(at13)!,
          isTrue,
        );
      },
    );

    test('is null for a departure (not an arrival)', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: false,
        flightDepartureTime: dep,
        flightTime: arr,
      );
      expect(ride.flightProgressFraction(DateTime(2026, 3, 15, 13, 0)), isNull);
    });

    test('is null when the take-off time is unknown', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightTime: arr, // no flightDepartureTime
      );
      expect(ride.flightProgressFraction(DateTime(2026, 3, 15, 13, 0)), isNull);
    });
  });
}
