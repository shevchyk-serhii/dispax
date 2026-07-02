// Unit tests for MucFlight (the arrivals-board row model): JSON parsing (times to local)
// and the delay getters.

import 'package:dispax/modules/flight_management/models/muc_flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MucFlight.fromJson', () {
    test('parses all fields and converts times to local', () {
      final f = MucFlight.fromJson({
        'flightNumber': 'LH1751',
        'status': 'landed',
        'scheduledTime': '2026-06-27T12:30:00Z',
        'estimatedTime': '2026-06-27T12:25:00Z',
        'terminal': 'T2',
        'gate': 'K12',
        'airline': 'Lufthansa',
        'origin': 'ATH',
      });

      expect(f.flightNumber, 'LH1751');
      expect(f.status, 'landed');
      expect(f.terminal, 'T2');
      expect(f.origin, 'ATH');
      expect(f.scheduledTime!.isUtc, isFalse); // converted to local
      expect(f.scheduledTime!.toUtc().toIso8601String(), '2026-06-27T12:30:00.000Z');
    });

    test('tolerates missing optional fields, defaults status to unknown', () {
      final f = MucFlight.fromJson({'flightNumber': 'XQ986'});
      expect(f.flightNumber, 'XQ986');
      expect(f.status, 'unknown');
      expect(f.scheduledTime, isNull);
      expect(f.terminal, isNull);
    });
  });

  group('MucFlight delay', () {
    test('delayMinutes is estimated − scheduled', () {
      final f = MucFlight.fromJson({
        'flightNumber': 'LH1',
        'status': 'delayed',
        'scheduledTime': '2026-06-27T14:00:00Z',
        'estimatedTime': '2026-06-27T14:30:00Z',
      });
      expect(f.delayMinutes, 30);
      expect(f.isDelayed, isTrue);
    });

    test('isDelayed is true on a delayed status even without two times', () {
      final f = MucFlight.fromJson({
        'flightNumber': 'LH1',
        'status': 'delayed',
      });
      expect(f.delayMinutes, isNull);
      expect(f.isDelayed, isTrue);
    });

    test('on-time flight is not delayed', () {
      final f = MucFlight.fromJson({
        'flightNumber': 'LH1',
        'status': 'landed',
        'scheduledTime': '2026-06-27T14:00:00Z',
        'estimatedTime': '2026-06-27T14:00:00Z',
      });
      expect(f.isDelayed, isFalse);
    });
  });
}
