import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../ride_management/models/ride.dart';
import '../models/location.dart' as app_location;

/// Why [MapboxService.geocodeAddress] returned `null`. Callers currently only
/// see the `null` (which the create-ride form surfaces as a single "Address
/// could not be located" warning regardless of cause) — this classification
/// exists so the underlying reason can be logged and diagnosed on-device.
enum GeocodeFailureReason { noToken, httpError, malformedResponse, exception }

/// Builds a human-readable, cause-specific message for a failed geocode
/// request. Pure (no I/O) so it is unit-testable without mocking HTTP.
String describeGeocodeFailure({
  required GeocodeFailureReason reason,
  int? statusCode,
  Object? cause,
}) {
  switch (reason) {
    case GeocodeFailureReason.noToken:
      return 'MapboxService: MAPBOX_ACCESS_TOKEN not set, geocoding unavailable';
    case GeocodeFailureReason.httpError:
      return 'MapboxService: Geocoding failed with status $statusCode';
    case GeocodeFailureReason.malformedResponse:
      return 'MapboxService: unexpected geocoding response shape';
    case GeocodeFailureReason.exception:
      return 'MapboxService: Geocoding error: $cause';
  }
}

class MapboxService {
  static const String _accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  static String get accessToken {
    // Use a real check (not assert) so a missing token also surfaces in
    // release builds, where asserts are stripped and an empty token would
    // otherwise leave the map silently blank.
    if (_accessToken.isEmpty) {
      throw StateError('MAPBOX_ACCESS_TOKEN must be set via --dart-define');
    }
    return _accessToken;
  }

  /// Token without the `assert` — safe to read when an empty token is a valid
  /// (degraded) state, e.g. wiring the maps SDK at startup or feeding the
  /// address suggester. Returns `''` when unset instead of tripping the debug
  /// assertion in [accessToken].
  static String get accessTokenOrEmpty => _accessToken;

  static const double defaultLatitude = 48.1351;
  static const double defaultLongitude = 11.5820;

  static Future<geo.Position?> getCurrentLocation() async {
    bool serviceEnabled;
    geo.LocationPermission permission;

    serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return null;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await geo.Geolocator.getCurrentPosition();
    } catch (e) {
      return null;
    }
  }

  static Future<List<double>?> geocodeAddress(String address) async {
    if (_accessToken.isEmpty) {
      _logGeocodeFailure(
        describeGeocodeFailure(reason: GeocodeFailureReason.noToken),
      );
      return null;
    }

    try {
      final encoded = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json'
        '?access_token=$_accessToken&limit=1',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final coords = parseGeocodeCoordinates(jsonDecode(response.body));
        if (coords != null) return coords;
        _logGeocodeFailure(
          describeGeocodeFailure(
            reason: GeocodeFailureReason.malformedResponse,
          ),
        );
      } else {
        _logGeocodeFailure(
          describeGeocodeFailure(
            reason: GeocodeFailureReason.httpError,
            statusCode: response.statusCode,
          ),
        );
      }
    } catch (e) {
      _logGeocodeFailure(
        describeGeocodeFailure(
          reason: GeocodeFailureReason.exception,
          cause: e,
        ),
      );
    }

    return null;
  }

  /// Logs a geocoding failure via `dart:developer` `log()` (visible in the
  /// Xcode/Android Studio console and DevTools even in profile/release runs
  /// launched from an IDE, unlike `debugPrint` which release builds swallow)
  /// so the actual reason ("Address could not be located" can mean a missing
  /// token, an HTTP error, or a malformed response) is diagnosable on-device
  /// instead of collapsing into an indistinguishable `null`.
  static void _logGeocodeFailure(String message) {
    developer.log(message, name: 'MapboxService', level: 900);
  }

  /// Extracts `[latitude, longitude]` from a decoded Mapbox geocoding response.
  ///
  /// Returns null for any malformed/partial shape — missing `features`, an empty
  /// list, a missing or non-list `center`, or fewer than two numeric entries —
  /// instead of throwing. This is the part that used to crash the callers
  /// (`features[0]['center'] as List` then `coordinates[1].toDouble()`).
  ///
  /// Mapbox returns `center` as `[longitude, latitude]`; we return
  /// `[latitude, longitude]` to match the rest of the app.
  static List<double>? parseGeocodeCoordinates(dynamic data) {
    final features = data is Map ? data['features'] : null;
    if (features is! List || features.isEmpty) return null;

    final first = features.first;
    final center = first is Map ? first['center'] : null;
    if (center is! List ||
        center.length < 2 ||
        center[0] is! num ||
        center[1] is! num) {
      return null;
    }

    return [(center[1] as num).toDouble(), (center[0] as num).toDouble()];
  }

  /// Forward-geocode [query] into a short list of human-readable address
  /// suggestions (Mapbox `place_name`), biased to Munich/Germany. Used by the
  /// address picker to show live autocomplete while the user types.
  ///
  /// Returns `[]` (never throws) when the token is missing, the query is too
  /// short, the request fails, or the response is malformed — the picker falls
  /// back to manual entry / saved places in that case.
  static Future<List<String>> suggestAddresses(String query) async {
    final trimmed = query.trim();
    if (_accessToken.isEmpty || trimmed.length < 3) return const [];

    try {
      final encoded = Uri.encodeComponent(trimmed);
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json'
        '?access_token=$_accessToken'
        '&limit=5'
        '&country=de'
        '&proximity=$defaultLongitude,$defaultLatitude',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return parseGeocodeSuggestions(jsonDecode(response.body));
      }
      debugPrint(
        'MapboxService: Suggest failed with status ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('MapboxService: Suggest error: $e');
    }

    return const [];
  }

  /// Extracts the `place_name` of each feature from a decoded Mapbox geocoding
  /// response, skipping any feature without a non-empty string name. Returns an
  /// empty list (never throws) for any malformed shape — missing/non-list
  /// `features`, non-Map features, missing/non-string `place_name`.
  static List<String> parseGeocodeSuggestions(dynamic data) {
    final features = data is Map ? data['features'] : null;
    if (features is! List) return const [];

    final result = <String>[];
    for (final feature in features) {
      final name = feature is Map ? feature['place_name'] : null;
      if (name is String && name.trim().isNotEmpty) {
        result.add(name);
      }
    }
    return result;
  }

  static CameraOptions createCameraOptions({
    required double latitude,
    required double longitude,
    double zoom = 14.0,
  }) {
    return CameraOptions(
      center: Point(coordinates: Position(longitude, latitude)),
      zoom: zoom,
    );
  }

  static Future<List<Position>> getRoutePoints(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) async {
    return [Position(fromLng, fromLat), Position(toLng, toLat)];
  }

  static CircleAnnotationOptions createLocationMarker({
    required double latitude,
    required double longitude,
    required String color,
    double radius = 8.0,
  }) {
    return CircleAnnotationOptions(
      geometry: Point(coordinates: Position(longitude, latitude)),
      circleRadius: radius,
      circleColor: _parseColor(color),
      circleStrokeWidth: 2.0,
      circleStrokeColor: 0xFFFFFFFF,
    );
  }

  static int _parseColor(String color) {
    switch (color.toLowerCase()) {
      case 'green':
        return 0xFF4CAF50;
      case 'red':
        return 0xFFF44336;
      case 'blue':
        return 0xFF2196F3;
      case 'orange':
        return 0xFFFF9800;
      case 'purple':
        return 0xFF9C27B0;
      default:
        return 0xFF2196F3;
    }
  }

  /// Driver position marker.
  ///
  /// [color] is a 32-bit ARGB int (typically
  /// `RideStatusStyles.getStatusColorValue(ride.status)`) so the dot follows the
  /// ride status palette per the design; [radius] is animated by the caller to
  /// produce the live pulse.
  static CircleAnnotationOptions createDriverMarker({
    required double latitude,
    required double longitude,
    required int color,
    double radius = 12.0,
    String? driverId,
  }) {
    return CircleAnnotationOptions(
      geometry: Point(coordinates: Position(longitude, latitude)),
      circleRadius: radius,
      circleColor: color,
      circleStrokeWidth: 3.0,
      circleStrokeColor: 0xFFFFFFFF,
    );
  }

  /// Client (self) position marker — the design's pulsing cyan dot.
  ///
  /// [color] defaults to the corporate accent (`#0EA5E9`); [radius] is animated
  /// by the caller for the pulse.
  static CircleAnnotationOptions createClientMarker({
    required double latitude,
    required double longitude,
    int color = 0xFF0EA5E9,
    double radius = 9.0,
  }) {
    return CircleAnnotationOptions(
      geometry: Point(coordinates: Position(longitude, latitude)),
      circleRadius: radius,
      circleColor: color,
      circleStrokeWidth: 3.0,
      circleStrokeColor: 0xFFFFFFFF,
    );
  }

  static List<CircleAnnotationOptions> createRideMarkers({
    required app_location.Location from,
    required app_location.Location to,
  }) {
    final List<CircleAnnotationOptions> markers = [];

    final fromLat = from.latitude;
    final fromLng = from.longitude;
    if (fromLat != null && fromLng != null) {
      markers.add(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(fromLng, fromLat)),
          circleRadius: 8.0,
          circleColor: _parseColor('green'),
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF,
        ),
      );
    }

    final toLat = to.latitude;
    final toLng = to.longitude;
    if (toLat != null && toLng != null) {
      markers.add(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(toLng, toLat)),
          circleRadius: 8.0,
          circleColor: _parseColor('red'),
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF,
        ),
      );
    }

    return markers;
  }

  static CameraOptions getCameraForRoute({
    required app_location.Location from,
    required app_location.Location to,
    geo.Position? currentPosition,
  }) {
    final List<Position> positions = [];

    final fromLat = from.latitude;
    final fromLng = from.longitude;
    if (fromLat != null && fromLng != null) {
      positions.add(Position(fromLng, fromLat));
    }

    final toLat = to.latitude;
    final toLng = to.longitude;
    if (toLat != null && toLng != null) {
      positions.add(Position(toLng, toLat));
    }

    if (currentPosition != null) {
      positions.add(
        Position(currentPosition.longitude, currentPosition.latitude),
      );
    }

    if (positions.isEmpty) {
      return createCameraOptions(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        zoom: 12.0,
      );
    }

    if (positions.length == 1) {
      return CameraOptions(
        center: Point(coordinates: positions.first),
        zoom: 15.0,
      );
    }

    double minLat = positions
        .map((p) => p.lat)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
    double maxLat = positions
        .map((p) => p.lat)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    double minLng = positions
        .map((p) => p.lng)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
    double maxLng = positions
        .map((p) => p.lng)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    double centerLat = (minLat + maxLat) / 2;
    double centerLng = (minLng + maxLng) / 2;

    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 15.0;
    if (maxDiff > 0.1) {
      zoom = 10.0;
    } else if (maxDiff > 0.05) {
      zoom = 12.0;
    } else if (maxDiff > 0.02) {
      zoom = 13.0;
    } else if (maxDiff > 0.01) {
      zoom = 14.0;
    }

    return CameraOptions(
      center: Point(coordinates: Position(centerLng, centerLat)),
      zoom: zoom,
    );
  }

  static bool isRideInProgress(Ride ride) {
    return ride.status == RideStatus.assigned ||
        ride.status == RideStatus.inProgress;
  }

  static Future<void> addDefaultImages(MapboxMap mapboxMap) async {
    try {} catch (e) {
      developer.log('Error adding marker images: $e', name: 'MapboxService');
    }
  }
}
