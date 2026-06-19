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
}
