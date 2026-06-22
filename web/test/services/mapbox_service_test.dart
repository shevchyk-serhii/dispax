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
