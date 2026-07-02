// Locks in Ride.withFlightFrom — the single helper all three manual flight-refresh
// handlers (details screen, driver/dispatcher Heute card, dispatcher pending row) use to
// patch ONLY the flight fields. It must copy gate/terminal/status/times from the fresh
// (not-fully-enriched) refresh DTO while preserving driverName/optimalEntryTime/avatar/eta;
// otherwise pushing the result into the shared RideBloc blanks those on the list cards.

import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  group('Ride.withFlightFrom', () {
    final enriched = TestFixtures.ride(
      isAirportTransfer: true,
      isArrival: true,
      flightNumber: 'LH123',
      flightTime: DateTime(2026, 6, 29, 10, 0),
      flightScheduledTime: DateTime(2026, 6, 29, 10, 0),
      gate: 'G12',
      terminal: '2',
      flightStatus: 'scheduled',
      driverName: 'Anna Driver',
      optimalEntryTime: DateTime(2026, 6, 29, 9, 40),
    ).copyWith(etaMinutes: 7);

    test('copies the flight fields and preserves enrichment', () {
      // A fresh refresh DTO: new flight data, but NO enrichment (driverName/eta/...).
      final fresh = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightNumber: 'LH123',
        flightTime: DateTime(2026, 6, 29, 10, 20),
        gate: 'H18',
        terminal: '1',
        flightStatus: 'landed',
      );

      final patched = enriched.withFlightFrom(fresh);

      // Flight fields updated from `fresh`...
      expect(patched.gate, 'H18');
      expect(patched.terminal, '1');
      expect(patched.flightStatus, 'landed');
      expect(patched.flightTime, DateTime(2026, 6, 29, 10, 20));
      // ...enrichment from the original survives (would be null on a wholesale replace).
      expect(patched.driverName, 'Anna Driver');
      expect(patched.optimalEntryTime, DateTime(2026, 6, 29, 9, 40));
      expect(patched.etaMinutes, 7);
    });

    test('keeps the existing time when the fresh ride has none (not-found)', () {
      // notFound refresh: fresh carries no flight time → keep what we had, don't erase.
      final fresh = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightNumber: 'LH123',
        gate: 'G12',
        terminal: '2',
        flightStatus: 'unknown',
      );

      final patched = enriched.withFlightFrom(fresh);

      expect(patched.flightTime, DateTime(2026, 6, 29, 10, 0)); // preserved
      expect(patched.driverName, 'Anna Driver');
    });
  });
}
