import 'package:dispax/modules/flight_management/flight_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightTracker.flightradarUrl', () {
    test('builds the Flightradar24 per-flight URL, lower-cased, no spaces', () {
      expect(
        FlightTracker.flightradarUrl('LH429').toString(),
        'https://www.flightradar24.com/data/flights/lh429',
      );
    });

    test('strips internal spaces from the flight number', () {
      expect(
        FlightTracker.flightradarUrl('LH 429').toString(),
        'https://www.flightradar24.com/data/flights/lh429',
      );
    });

    test('returns null for a null or blank number (nothing to link to)', () {
      expect(FlightTracker.flightradarUrl(null), isNull);
      expect(FlightTracker.flightradarUrl(''), isNull);
      expect(FlightTracker.flightradarUrl('   '), isNull);
    });
  });
}
