import 'dart:math' as math;

import '../services/mapbox_service.dart';

/// Outcome of checking whether an address can be served by the fleet.
///
/// This is a soft, advisory check shown in the create-ride form — it never
/// blocks ride creation, it only warns the dispatcher (see the create-ride
/// location section). "Reachable" here means the address geocoded to a real
/// point that lies within the MVP service zone (Munich + suburbs).
enum Reachability {
  /// Geocoded successfully and within the service zone.
  reachable,

  /// Geocoded successfully but farther than [ServiceZone.radiusKm] from the
  /// service-zone center.
  outOfArea,

  /// Could not be geocoded at all — no real address matched, or geocoding was
  /// unavailable (e.g. missing Mapbox token).
  notFound,
}

/// The result of a reachability check, carrying the verdict plus the distance
/// from the service-zone center when coordinates were resolved.
class ReachabilityResult {
  final Reachability status;

  /// Distance in kilometers from the service-zone center, or `null` when the
  /// address could not be geocoded ([Reachability.notFound]).
  final double? distanceKm;

  const ReachabilityResult(this.status, {this.distanceKm});

  bool get isReachable => status == Reachability.reachable;
}

/// MVP service zone: Munich and its suburbs, up to 100 km from the city center.
///
/// The center reuses [MapboxService.defaultLatitude] / [defaultLongitude] (the
/// Munich bias already used for map defaults and address suggestions) so there
/// is a single source of truth for "where Munich is".
class ServiceZone {
  static const double centerLatitude = MapboxService.defaultLatitude;
  static const double centerLongitude = MapboxService.defaultLongitude;

  /// Maximum supported distance from the center, in kilometers (per the MVP
  /// requirements: Munich + suburbs up to 100 km).
  static const double radiusKm = 100.0;

  static const double _earthRadiusKm = 6371.0;

  /// Great-circle (Haversine) distance in kilometers between two points.
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Distance in kilometers of [lat]/[lng] from the service-zone center.
  static double distanceFromCenterKm(double lat, double lng) =>
      distanceKm(centerLatitude, centerLongitude, lat, lng);

  /// Classifies a pair of already-resolved coordinates against the service zone.
  ///
  /// Pass `null` coordinates (e.g. when geocoding returned nothing) to get
  /// [Reachability.notFound].
  static ReachabilityResult classify(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return const ReachabilityResult(Reachability.notFound);
    }
    final distance = distanceFromCenterKm(lat, lng);
    final status = distance > radiusKm
        ? Reachability.outOfArea
        : Reachability.reachable;
    return ReachabilityResult(status, distanceKm: distance);
  }

  /// Geocodes [address] (via Mapbox) and classifies it against the service zone.
  ///
  /// Returns [Reachability.notFound] when the address does not geocode (no
  /// match, or geocoding unavailable). A blank address is treated as
  /// not-found without hitting the network.
  static Future<ReachabilityResult> reachabilityOf(String address) async {
    if (address.trim().isEmpty) {
      return const ReachabilityResult(Reachability.notFound);
    }
    final coords = await MapboxService.geocodeAddress(address);
    if (coords == null || coords.length < 2) {
      return const ReachabilityResult(Reachability.notFound);
    }
    return classify(coords[0], coords[1]);
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
