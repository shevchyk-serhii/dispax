@Tags(['integration'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'helpers.dart';

void main() {
  late String clientToken;

  setUpAll(() async {
    clientToken = await tryLoginAs(kClientEmail, kPassword);
  });

  group('Backend → Flutter contract (GET /rides)', () {
    late List<dynamic> rawRides;
    late List<Ride> parsedRides;

    setUpAll(() async {
      final client = makeClient(token: clientToken);
      try {
        final response = await client.get('/rides');
        expect(
          response.statusCode,
          200,
          reason: 'Backend must return 200 for authenticated request',
        );
        rawRides = jsonDecode(response.body) as List;
        parsedRides = rawRides
            .map((r) => Ride.fromJson(r as Map<String, dynamic>))
            .toList();
      } finally {
        client.dispose();
      }
    });

    test('backend returns a non-empty list of rides', () {
      expect(parsedRides, isNotEmpty);
    });

    test('all required fields are present in every ride', () {
      for (final raw in rawRides) {
        final ride = raw as Map<String, dynamic>;
        expect(ride.containsKey('id'), isTrue, reason: 'missing id');
        expect(ride.containsKey('status'), isTrue, reason: 'missing status');
        expect(
          ride.containsKey('pickupDateTime'),
          isTrue,
          reason: 'missing pickupDateTime',
        );
        expect(ride.containsKey('from'), isTrue, reason: 'missing from');
        expect(ride.containsKey('to'), isTrue, reason: 'missing to');
        expect(
          ride.containsKey('clientName'),
          isTrue,
          reason: 'missing clientName',
        );
        expect(
          ride.containsKey('isAirportTransfer'),
          isTrue,
          reason: 'missing isAirportTransfer',
        );
      }
    });

    // Note: Ride.fromJson converts pickupDateTime to local time (.toLocal())
    // for display, so the parsed value is intentionally not UTC. The wire
    // contract (UTC with a trailing Z) is asserted at the JSON level below.

    test('pickupDateTime in JSON ends with Z (UTC format)', () {
      for (final raw in rawRides) {
        final ride = raw as Map<String, dynamic>;
        final dt = ride['pickupDateTime'] as String;
        expect(
          dt.endsWith('Z'),
          isTrue,
          reason:
              'pickupDateTime must end with Z (UTC), got: $dt for ride ${ride['id']}',
        );
      }
    });

    test('status parses into a known RideStatus (not a fallback)', () {
      final knownStatuses = {
        'requested',
        'assigned',
        'inprogress',
        'completed',
        'cancelled',
      };
      for (final raw in rawRides) {
        final ride = raw as Map<String, dynamic>;
        final statusStr = (ride['status'] as String).toLowerCase();
        expect(
          knownStatuses.contains(statusStr),
          isTrue,
          reason:
              'Unknown status "${ride['status']}" — Flutter will silently fallback to requested',
        );
      }
    });

    test('Ride.fromJson does not throw for any ride', () {
      expect(
        () => rawRides
            .map((r) => Ride.fromJson(r as Map<String, dynamic>))
            .toList(),
        returnsNormally,
      );
    });

    test('from and to contain an address', () {
      for (final raw in rawRides) {
        final ride = raw as Map<String, dynamic>;
        for (final key in ['from', 'to']) {
          final loc = ride[key] as Map<String, dynamic>;
          expect(
            loc.containsKey('address'),
            isTrue,
            reason: '$key missing address',
          );
        }
      }
    });

    test('airport transfer rides expose the arrival flag', () {
      final airportRides = rawRides
          .where((r) => r['isAirportTransfer'] == true)
          .toList();

      if (airportRides.isEmpty) return; // mock may contain no airport rides

      for (final raw in airportRides) {
        final ride = raw as Map<String, dynamic>;
        expect(
          ride.containsKey('isArrival'),
          isTrue,
          reason: 'airport ride missing isArrival',
        );
      }
    });

    test('Flutter Ride objects are equal on re-parse (fromJson is stable)', () {
      final first = rawRides
          .map((r) => Ride.fromJson(r as Map<String, dynamic>))
          .toList();
      final second = rawRides
          .map((r) => Ride.fromJson(r as Map<String, dynamic>))
          .toList();

      for (var i = 0; i < first.length; i++) {
        expect(
          first[i],
          second[i],
          reason: 'fromJson not stable for ride ${first[i].id}',
        );
      }
    });
  });
}
