import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/models/ride_estimate.dart';

void main() {
  group('RideEstimate.fromJson', () {
    Map<String, dynamic> json0({Object? currency = 'EUR'}) => {
      'distanceKm': 12.4,
      'durationMinutes': 18,
      'estimatedPrice': 34.5,
      if (currency != null) 'currency': currency,
    };

    test('parses all required fields', () {
      final e = RideEstimate.fromJson(json0());
      expect(e.distanceKm, 12.4);
      expect(e.durationMinutes, 18);
      expect(e.estimatedPrice, 34.5);
      expect(e.currency, 'EUR');
    });

    test('falls back to EUR when currency is missing', () {
      final e = RideEstimate.fromJson(json0(currency: null));
      expect(e.currency, 'EUR');
    });

    test('falls back to EUR when currency is not a string', () {
      final e = RideEstimate.fromJson(json0(currency: 42));
      expect(e.currency, 'EUR');
    });

    test('throws naming a missing required double field', () {
      final json = json0()..remove('distanceKm');
      expect(
        () => RideEstimate.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('distanceKm'),
          ),
        ),
      );
    });

    test('throws naming a missing required int field', () {
      final json = json0()..remove('durationMinutes');
      expect(
        () => RideEstimate.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('durationMinutes'),
          ),
        ),
      );
    });

    test('throws on a null required price instead of crashing', () {
      final json = json0()..['estimatedPrice'] = null;
      expect(
        () => RideEstimate.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
