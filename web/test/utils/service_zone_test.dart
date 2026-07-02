import 'package:dispax/modules/core/utils/service_zone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServiceZone.classify', () {
    test('null coordinates -> notFound', () {
      final result = ServiceZone.classify(null, null);
      expect(result.status, Reachability.notFound);
      expect(result.distanceKm, isNull);
      expect(result.isReachable, isFalse);
    });

    test('Munich center -> reachable, distance ~0', () {
      final result = ServiceZone.classify(
        ServiceZone.centerLatitude,
        ServiceZone.centerLongitude,
      );
      expect(result.status, Reachability.reachable);
      expect(result.isReachable, isTrue);
      expect(result.distanceKm, isNotNull);
      expect(result.distanceKm!, lessThan(1.0));
    });

    test('Munich suburb (~25 km, airport MUC) -> reachable', () {
      // Munich Airport (MUC) ~28.7 km north-east of the city center.
      final result = ServiceZone.classify(48.3538, 11.7861);
      expect(result.status, Reachability.reachable);
      expect(result.distanceKm!, greaterThan(20.0));
      expect(result.distanceKm!, lessThan(ServiceZone.radiusKm));
    });

    test('Berlin (~500 km) -> outOfArea', () {
      // Berlin center, well beyond the 100 km service radius.
      final result = ServiceZone.classify(52.5200, 13.4050);
      expect(result.status, Reachability.outOfArea);
      expect(result.isReachable, isFalse);
      // Mutation guard: if the radius check were broadened (e.g. > 100000),
      // this would flip to reachable and the test would go red.
      expect(result.distanceKm!, greaterThan(ServiceZone.radiusKm));
    });

    test('just outside the radius -> outOfArea, just inside -> reachable', () {
      // ~1 degree of latitude ≈ 111 km, so +1.0° north is clearly out of zone
      // and a small offset stays in zone — pins the threshold direction.
      final outside = ServiceZone.classify(
        ServiceZone.centerLatitude + 1.0,
        ServiceZone.centerLongitude,
      );
      final inside = ServiceZone.classify(
        ServiceZone.centerLatitude + 0.5,
        ServiceZone.centerLongitude,
      );
      expect(outside.status, Reachability.outOfArea);
      expect(inside.status, Reachability.reachable);
    });
  });

  group('ServiceZone.distanceKm (Haversine)', () {
    test('same point -> 0', () {
      expect(
        ServiceZone.distanceKm(48.0, 11.0, 48.0, 11.0),
        closeTo(0.0, 1e-9),
      );
    });

    test('one degree of latitude ~111 km', () {
      final d = ServiceZone.distanceKm(48.0, 11.0, 49.0, 11.0);
      expect(d, closeTo(111.0, 2.0));
    });

    test('is symmetric', () {
      final ab = ServiceZone.distanceKm(48.1, 11.5, 52.5, 13.4);
      final ba = ServiceZone.distanceKm(52.5, 13.4, 48.1, 11.5);
      expect(ab, closeTo(ba, 1e-9));
    });
  });
}
