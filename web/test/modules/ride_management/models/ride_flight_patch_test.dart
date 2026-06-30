// Locks in the invariant the manual flight-refresh relies on: patching ONLY the flight
// fields via copyWith must preserve the ride's enrichment (driverName, optimalEntryTime,
// clientHasAvatar, etaMinutes). The refresh endpoint returns a not-fully-enriched DTO, so
// the details screen copyWith-patches instead of replacing the whole ride — otherwise the
// shared RideBloc's copy gets de-enriched and list cards blank those fields.

import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  test('copyWith of flight fields preserves enrichment fields', () {
    final enriched = TestFixtures.ride(
      isAirportTransfer: true,
      isArrival: true,
      flightNumber: 'LH123',
      flightTime: DateTime(2026, 6, 29, 10, 0),
      gate: 'G12',
      terminal: '2',
      flightStatus: 'scheduled',
      driverName: 'Anna Driver',
      optimalEntryTime: DateTime(2026, 6, 29, 9, 40),
    ).copyWith(etaMinutes: 7);

    // Patch only the flight fields (as the refresh handler does).
    final patched = enriched.copyWith(
      gate: 'H18',
      terminal: '1',
      flightStatus: 'landed',
      flightTime: DateTime(2026, 6, 29, 10, 20),
    );

    // Flight fields updated...
    expect(patched.gate, 'H18');
    expect(patched.terminal, '1');
    expect(patched.flightStatus, 'landed');
    expect(patched.flightTime, DateTime(2026, 6, 29, 10, 20));
    // ...enrichment survives.
    expect(patched.driverName, 'Anna Driver');
    expect(patched.optimalEntryTime, DateTime(2026, 6, 29, 9, 40));
    expect(patched.etaMinutes, 7);
  });
}
