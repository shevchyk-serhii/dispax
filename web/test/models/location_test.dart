import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/core/models/location.dart';

void main() {
  group('Location', () {
    test('fromJson creates Location correctly', () {
      final json = {
        'address': '123 Main St',
        'latitude': 48.1351,
        'longitude': 11.5820,
      };

      final location = Location.fromJson(json);

      expect(location.address, '123 Main St');
      expect(location.latitude, 48.1351);
      expect(location.longitude, 11.5820);
    });

    test('toJson produces correct map', () {
      const location = Location(
        address: '123 Main St',
        latitude: 48.1351,
        longitude: 11.5820,
      );

      final json = location.toJson();

      expect(json['address'], '123 Main St');
      expect(json['latitude'], 48.1351);
      expect(json['longitude'], 11.5820);
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = Location(
        address: 'Test Str 42',
        latitude: 48.0,
        longitude: 11.0,
      );

      final restored = Location.fromJson(original.toJson());

      expect(restored, original);
    });

    test('fromJson handles null coordinates', () {
      final json = {'address': 'No coords'};

      final location = Location.fromJson(json);

      expect(location.address, 'No coords');
      expect(location.latitude, isNull);
      expect(location.longitude, isNull);
    });

    test('fromJson handles null address as empty string', () {
      final json = <String, dynamic>{
        'latitude': 48.0,
        'longitude': 11.0,
      };

      final location = Location.fromJson(json);

      expect(location.address, '');
    });

    test('equality compares all fields', () {
      const a = Location(address: 'A', latitude: 1.0, longitude: 2.0);
      const b = Location(address: 'A', latitude: 1.0, longitude: 2.0);
      const c = Location(address: 'B', latitude: 1.0, longitude: 2.0);

      expect(a, b);
      expect(a, isNot(c));
    });

    test('hashCode is consistent with equality', () {
      const a = Location(address: 'A', latitude: 1.0, longitude: 2.0);
      const b = Location(address: 'A', latitude: 1.0, longitude: 2.0);

      expect(a.hashCode, b.hashCode);
    });

    test('toString returns address', () {
      const location = Location(address: 'My Street 5');

      expect(location.toString(), 'My Street 5');
    });
  });
}
