// Unit coverage for the airport catalog used to auto-fill the ride form's
// airport endpoint. The critical guarantee is that a known airport address
// resolves to a Location carrying real coordinates (so downstream ETA/distance
// works), and that a plain address does not.

import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/helpers/airport_catalog.dart';

void main() {
  group('locationForAddress', () {
    test('a catalog airport address carries its coordinates', () {
      final loc = locationForAddress(defaultAirport.address);
      expect(loc.address, defaultAirport.address);
      expect(loc.latitude, 48.3537);
      expect(loc.longitude, 11.786);
    });

    test('a catalog airport address is matched after trimming whitespace', () {
      final loc = locationForAddress('  ${defaultAirport.address}  ');
      expect(loc.latitude, 48.3537);
      expect(loc.longitude, 11.786);
    });

    test('a plain address has no coordinates', () {
      final loc = locationForAddress('Marienplatz 1, München');
      expect(loc.address, 'Marienplatz 1, München');
      expect(loc.latitude, isNull);
      expect(loc.longitude, isNull);
    });
  });

  group('isCatalogAirportAddress', () {
    test('true for the canonical MUC address', () {
      expect(isCatalogAirportAddress(defaultAirport.address), isTrue);
    });

    test('false for a non-airport address', () {
      expect(isCatalogAirportAddress('Marienplatz 1'), isFalse);
    });
  });

  group('defaultAirport', () {
    test('is MUC with the canonical label', () {
      expect(defaultAirport.code, 'MUC');
      expect(defaultAirport.label, 'Flughafen München (MUC)');
    });
  });
}
