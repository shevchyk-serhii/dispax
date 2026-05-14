import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('CreateRideRequest', () {
    test('toJson serializes all fields', () {
      final request = TestFixtures.createRideRequest(
        clientId: 'c1',
        creatorId: 'cr1',
        companyId: 'co1',
        clientName: 'Test Client',
        flightNumber: 'LH999',
        isAirportTransfer: true,
      );

      final json = request.toJson();

      expect(json['clientId'], 'c1');
      expect(json['creatorId'], 'cr1');
      expect(json['companyId'], 'co1');
      expect(json['clientName'], 'Test Client');
      expect(json['flightNumber'], 'LH999');
      expect(json['isAirportTransfer'], true);
      expect(json['status'], 'Requested');
      expect(json['pickupDateTime'], isA<String>());
      expect(json['from'], isA<Map>());
      expect(json['to'], isA<Map>());
    });

    test('toJson includes null flightNumber when not set', () {
      final request = TestFixtures.createRideRequest();
      final json = request.toJson();

      expect(json['flightNumber'], isNull);
      expect(json['isAirportTransfer'], false);
    });

    test('toJson serializes from/to locations correctly', () {
      final request = TestFixtures.createRideRequest();
      final json = request.toJson();

      expect(json['from']['address'], isA<String>());
      expect(json['to']['address'], isA<String>());
    });

    test('toJson serializes local DateTime as UTC (ends with Z)', () {
      final localTime = DateTime(2026, 3, 15, 10, 0); // local, not UTC
      final request = TestFixtures.createRideRequest(pickupDateTime: localTime);

      final json = request.toJson();
      final dateStr = json['pickupDateTime'] as String;

      expect(dateStr.endsWith('Z'), isTrue,
          reason: 'pickupDateTime must be UTC ISO-8601 (ending with Z), got: $dateStr');
    });

    test('toJson serializes UTC DateTime as UTC (ends with Z)', () {
      final utcTime = DateTime.utc(2026, 3, 15, 10, 0);
      final request = TestFixtures.createRideRequest(pickupDateTime: utcTime);

      final json = request.toJson();
      final dateStr = json['pickupDateTime'] as String;

      expect(dateStr.endsWith('Z'), isTrue,
          reason: 'pickupDateTime must be UTC ISO-8601 (ending with Z), got: $dateStr');
      expect(dateStr, '2026-03-15T10:00:00.000Z');
    });
  });
}
