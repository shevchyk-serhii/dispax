// Unit tests for the address-based airport detection used by the dispatcher's
// "Airport" filter. The filter must catch rides going to/from the airport even
// when the booker did not toggle the explicit `isAirportTransfer` flag.

import 'package:flutter_test/flutter_test.dart';

import 'package:dispax/modules/ride_management/helpers/airport_detection.dart';

import '../../helpers/test_fixtures.dart';

void main() {
  group('addressLooksLikeAirport', () {
    test('matches German "Flughafen"', () {
      expect(addressLooksLikeAirport('Flughafen München Terminal 2'), isTrue);
    });

    test('matches English "Airport"', () {
      expect(addressLooksLikeAirport('Munich Airport'), isTrue);
    });

    test('matches the MUC postal code', () {
      expect(
        addressLooksLikeAirport('Nordallee 25, 85356 München'),
        isTrue,
      );
    });

    test('is case-insensitive', () {
      expect(addressLooksLikeAirport('FLUGHAFEN'), isTrue);
    });

    test('rejects a plain city address', () {
      expect(addressLooksLikeAirport('Marienplatz, München'), isFalse);
    });
  });

  group('isAirportRide', () {
    test('true when the explicit flag is set', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        from: TestFixtures.location(address: 'Marienplatz'),
        to: TestFixtures.location(address: 'Leopoldstraße'),
      );
      expect(isAirportRide(ride), isTrue);
    });

    test('true when the pickup address is the airport (no flag)', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: false,
        from: TestFixtures.location(address: 'Flughafen München'),
        to: TestFixtures.location(address: 'Marienplatz'),
      );
      expect(isAirportRide(ride), isTrue);
    });

    test('true when the drop-off address is the airport (no flag)', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: false,
        from: TestFixtures.location(address: 'Marienplatz'),
        to: TestFixtures.location(address: 'Munich Airport'),
      );
      expect(isAirportRide(ride), isTrue);
    });

    test('false for a non-airport ride without the flag', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: false,
        from: TestFixtures.location(address: 'Marienplatz'),
        to: TestFixtures.location(address: 'Ostbahnhof'),
      );
      expect(isAirportRide(ride), isFalse);
    });
  });
}
