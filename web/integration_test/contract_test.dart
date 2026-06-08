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

  group('Backend → Flutter contract (GET /rides/mock)', () {
    late List<dynamic> rawRides;
    late List<Ride> parsedRides;

    setUpAll(() async {
      final client = makeClient(token: clientToken);
      try {
        final response = await client.get('/rides/mock');
        expect(response.statusCode, 200,
            reason: 'Backend must return 200 for authenticated request');
        rawRides = jsonDecode(response.body) as List;
        parsedRides = rawRides
            .map((r) => Ride.fromJson(r as Map<String, dynamic>))
            .toList();
      } finally {
        client.dispose();
      }
    });

    test('бекенд возвращает непустой список поездок', () {
      expect(parsedRides, isNotEmpty);
    });

    test('все обязательные поля присутствуют в каждой поездке', () {
      for (final raw in rawRides) {
        final ride = raw as Map<String, dynamic>;
        expect(ride.containsKey('id'), isTrue, reason: 'missing id');
        expect(ride.containsKey('status'), isTrue, reason: 'missing status');
        expect(ride.containsKey('pickupDateTime'), isTrue,
            reason: 'missing pickupDateTime');
        expect(ride.containsKey('from'), isTrue, reason: 'missing from');
        expect(ride.containsKey('to'), isTrue, reason: 'missing to');
        expect(ride.containsKey('clientName'), isTrue,
            reason: 'missing clientName');
        expect(ride.containsKey('isAirportTransfer'), isTrue,
            reason: 'missing isAirportTransfer');
      }
    });

    test('pickupDateTime парсится как UTC (isUtc == true)', () {
      for (final ride in parsedRides) {
        expect(ride.pickupDateTime.isUtc, isTrue,
            reason:
                'pickupDateTime must be UTC, got: ${ride.pickupDateTime} for ride ${ride.id}');
      }
    });

    test('pickupDateTime в JSON заканчивается на Z (UTC формат)', () {
      for (final raw in rawRides) {
        final ride = raw as Map<String, dynamic>;
        final dt = ride['pickupDateTime'] as String;
        expect(dt.endsWith('Z'), isTrue,
            reason:
                'pickupDateTime must end with Z (UTC), got: $dt for ride ${ride['id']}');
      }
    });

    test('status парсится в известный RideStatus (не fallback)', () {
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
        expect(knownStatuses.contains(statusStr), isTrue,
            reason:
                'Unknown status "${ride['status']}" — Flutter will silently fallback to requested');
      }
    });

    test('Ride.fromJson не бросает исключений ни для одной поездки', () {
      expect(
        () => rawRides
            .map((r) => Ride.fromJson(r as Map<String, dynamic>))
            .toList(),
        returnsNormally,
      );
    });

    test('from и to содержат address, latitude, longitude', () {
      for (final raw in rawRides) {
        final ride = raw as Map<String, dynamic>;
        for (final key in ['from', 'to']) {
          final loc = ride[key] as Map<String, dynamic>;
          expect(loc.containsKey('address'), isTrue,
              reason: '$key missing address');
          expect(loc.containsKey('latitude'), isTrue,
              reason: '$key missing latitude');
          expect(loc.containsKey('longitude'), isTrue,
              reason: '$key missing longitude');
        }
      }
    });

    test('airport transfer поездки содержат flight поля', () {
      final airportRides =
          rawRides.where((r) => r['isAirportTransfer'] == true).toList();

      if (airportRides.isEmpty) return; // mock может не содержать airport rides

      for (final raw in airportRides) {
        final ride = raw as Map<String, dynamic>;
        expect(ride.containsKey('flightNumber'), isTrue,
            reason: 'airport ride missing flightNumber');
        expect(ride.containsKey('isArrival'), isTrue,
            reason: 'airport ride missing isArrival');
      }
    });

    test('Flutter Ride объекты равны при повторном парсинге (fromJson стабилен)',
        () {
      final first = rawRides
          .map((r) => Ride.fromJson(r as Map<String, dynamic>))
          .toList();
      final second = rawRides
          .map((r) => Ride.fromJson(r as Map<String, dynamic>))
          .toList();

      for (var i = 0; i < first.length; i++) {
        expect(first[i], second[i],
            reason: 'fromJson not stable for ride ${first[i].id}');
      }
    });
  });
}
