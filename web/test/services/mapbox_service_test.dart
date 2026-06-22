import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/core/services/mapbox_service.dart';

void main() {
  group('MapboxService.parseGeocodeCoordinates', () {
    test('returns [lat, lng] from a well-formed response', () {
      // Mapbox center is [lng, lat]; we expect [lat, lng] back.
      final data = {
        'features': [
          {
            'center': [11.582, 48.1351],
          },
        ],
      };

      expect(MapboxService.parseGeocodeCoordinates(data), [48.1351, 11.582]);
    });

    test('accepts integer coordinates', () {
      final data = {
        'features': [
          {
            'center': [11, 48],
          },
        ],
      };

      expect(MapboxService.parseGeocodeCoordinates(data), [48.0, 11.0]);
    });

    // Regression: each of these shapes used to throw (and crash the map / address
    // lookup) at `features[0]['center'] as List` or `coordinates[1].toDouble()`.
    test('returns null instead of throwing on malformed shapes', () {
      expect(MapboxService.parseGeocodeCoordinates(null), isNull);
      expect(MapboxService.parseGeocodeCoordinates('nonsense'), isNull);
      expect(MapboxService.parseGeocodeCoordinates({}), isNull);
      expect(MapboxService.parseGeocodeCoordinates({'features': []}), isNull);
      expect(
        MapboxService.parseGeocodeCoordinates({
          'features': [
            {'name': 'no center'},
          ],
        }),
        isNull,
      );
      expect(
        MapboxService.parseGeocodeCoordinates({
          'features': [
            {'center': 'not a list'},
          ],
        }),
        isNull,
      );
      expect(
        MapboxService.parseGeocodeCoordinates({
          'features': [
            {
              'center': [11.582],
            },
          ],
        }),
        isNull,
      );
      expect(
        MapboxService.parseGeocodeCoordinates({
          'features': [
            {
              'center': ['x', 'y'],
            },
          ],
        }),
        isNull,
      );
    });
  });

  group('MapboxService.parseGeocodeSuggestions', () {
    test('returns the place_name of each feature, in order', () {
      final data = {
        'features': [
          {'place_name': 'Marienplatz, 80331 München'},
          {'place_name': 'Marienstraße 1, 80333 München'},
        ],
      };

      expect(MapboxService.parseGeocodeSuggestions(data), [
        'Marienplatz, 80331 München',
        'Marienstraße 1, 80333 München',
      ]);
    });

    test('skips features without a usable string place_name', () {
      final data = {
        'features': [
          {'place_name': 'Keep me, München'},
          {'text': 'no place_name'},
          {'place_name': 42},
          {'place_name': '   '},
          'not a map',
        ],
      };

      expect(MapboxService.parseGeocodeSuggestions(data), ['Keep me, München']);
    });

    test('returns [] instead of throwing on malformed shapes', () {
      expect(MapboxService.parseGeocodeSuggestions(null), isEmpty);
      expect(MapboxService.parseGeocodeSuggestions('nonsense'), isEmpty);
      expect(MapboxService.parseGeocodeSuggestions({}), isEmpty);
      expect(MapboxService.parseGeocodeSuggestions({'features': []}), isEmpty);
      expect(
        MapboxService.parseGeocodeSuggestions({'features': 'not a list'}),
        isEmpty,
      );
    });
  });

  group('MapboxService marker colours', () {
    test('createDriverMarker uses the provided status colour', () {
      final marker = MapboxService.createDriverMarker(
        latitude: 48.0,
        longitude: 11.0,
        color: 0xFF14B8A6, // in-progress teal
      );
      expect(marker.circleColor, 0xFF14B8A6);
    });

    test('createClientMarker defaults to the corporate accent (cyan)', () {
      final marker = MapboxService.createClientMarker(
        latitude: 48.0,
        longitude: 11.0,
      );
      expect(marker.circleColor, 0xFF0EA5E9);
    });

    test('marker radius is animatable via the radius argument', () {
      expect(
        MapboxService.createDriverMarker(
          latitude: 48.0,
          longitude: 11.0,
          color: 0xFF000000,
          radius: 15.0,
        ).circleRadius,
        15.0,
      );
      expect(
        MapboxService.createClientMarker(
          latitude: 48.0,
          longitude: 11.0,
          radius: 12.0,
        ).circleRadius,
        12.0,
      );
    });
  });
}
