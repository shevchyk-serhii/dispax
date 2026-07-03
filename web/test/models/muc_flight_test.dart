// fromJson hardening: the required flightNumber goes through JsonParse so a
// missing value throws a FormatException naming the field instead of an
// opaque TypeError (a single bad row used to break the whole arrivals board).

import 'package:dispax/modules/flight_management/models/muc_flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MucFlight.fromJson', () {
    Map<String, dynamic> json0() => {
      'flightNumber': 'LH1983',
      'status': 'landed',
      'scheduledTime': '2026-06-22T09:00:00Z',
      'terminal': 'T2',
    };

    test('parses required and optional fields', () {
      final flight = MucFlight.fromJson(json0());
      expect(flight.flightNumber, 'LH1983');
      expect(flight.status, 'landed');
      expect(flight.terminal, 'T2');
    });

    test('missing flightNumber throws a FormatException naming it', () {
      expect(
        () => MucFlight.fromJson(json0()..remove('flightNumber')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('flightNumber'),
          ),
        ),
      );
    });

    test('missing status degrades to "unknown"', () {
      expect(MucFlight.fromJson(json0()..remove('status')).status, 'unknown');
    });
  });
}
