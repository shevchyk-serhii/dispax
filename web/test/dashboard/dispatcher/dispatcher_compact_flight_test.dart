// Covers the compact dispatcher ride lists that gained flight info:
//  - driver_schedule_panel: driverScheduleRideLabel() prefixes airport rides
//    with the flight number.
//  - bulk_reassign_dialog: shows Ride.fullFlightInfo for airport rides (the
//    same isAirportTransfer && fullFlightInfo.isNotEmpty gate the panel uses).

import 'package:dispax/dashboard/dispatcher/widgets/driver_schedule_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_fixtures.dart';

void main() {
  group('driverScheduleRideLabel', () {
    test('prefixes an airport ride with the flight number', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightNumber: 'LH1671',
      );

      final label = driverScheduleRideLabel(ride);

      expect(label, contains('✈ LH1671'));
      expect(label, contains(ride.from.address));
    });

    test('omits the flight prefix for a non-airport ride', () {
      final ride = TestFixtures.ride(isAirportTransfer: false);

      final label = driverScheduleRideLabel(ride);

      expect(label, isNot(contains('✈')));
      expect(label, contains(ride.from.address));
    });

    test('appends the gate for an airport ride whose gate is known', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightNumber: 'LH1671',
        gate: 'G18',
        terminal: 'T2',
      );

      final label = driverScheduleRideLabel(ride);

      expect(label, contains('✈ LH1671'));
      expect(label, contains('Gate G18'));
    });

    test('omits the gate when it is unknown', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightNumber: 'LH1671',
      );

      final label = driverScheduleRideLabel(ride);

      expect(label, contains('✈ LH1671'));
      expect(label, isNot(contains('Gate')));
    });

    test('renders a remote stand as a bus gate, never the raw "REMOTE"', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightNumber: 'LH1671',
        gate: 'REMOTE',
        terminal: 'T2',
      );

      // No l10n passed → English fallback, but never the bare word "REMOTE"
      // and never the misleading "Gate REMOTE".
      final label = driverScheduleRideLabel(ride);

      expect(label, contains('Bus gate'));
      expect(label, isNot(contains('Gate REMOTE')));
    });
  });

  group('bulk reassign flight subtitle gate', () {
    test('airport ride exposes a non-empty fullFlightInfo with the gate', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightNumber: 'LH1671',
        gate: 'G18',
        terminal: 'T2',
      );

      // This is exactly what the bulk-reassign subtitle renders.
      expect(ride.isAirportTransfer && ride.fullFlightInfo.isNotEmpty, isTrue);
      expect(ride.fullFlightInfo, contains('Gate G18'));
    });

    test('non-airport ride yields an empty fullFlightInfo (row hidden)', () {
      final ride = TestFixtures.ride(isAirportTransfer: false);

      expect(ride.isAirportTransfer && ride.fullFlightInfo.isNotEmpty, isFalse);
    });
  });
}
