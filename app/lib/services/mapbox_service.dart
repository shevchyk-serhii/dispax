import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxService {
  static const String _accessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';

  // You'll need to set your Mapbox access token
  // Get it from https://account.mapbox.com/access-tokens/
  static String get accessToken => _accessToken;

  // Default Kiev coordinates
  static const double defaultLatitude = 50.4501;
  static const double defaultLongitude = 30.5234;

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
    // For now, return mock coordinates for Kiev addresses
    // In production, you'd use Mapbox Geocoding API
    if (address.toLowerCase().contains('downtown') ||
        address.toLowerCase().contains('центр')) {
      return [50.4501, 30.5234];
    } else if (address.toLowerCase().contains('airport') ||
        address.toLowerCase().contains('аэропорт')) {
      return [50.3457, 30.8944]; // Boryspil Airport
    } else if (address.toLowerCase().contains('railway') ||
        address.toLowerCase().contains('вокзал')) {
      return [50.4433, 30.4914]; // Central Railway Station
    } else if (address.toLowerCase().contains('university') ||
        address.toLowerCase().contains('университет')) {
      return [50.4434, 30.5059]; // Kiev National University
    } else if (address.toLowerCase().contains('independence') ||
        address.toLowerCase().contains('независимости')) {
      return [50.4501, 30.5241]; // Independence Square
    } else if (address.toLowerCase().contains('golden') ||
        address.toLowerCase().contains('золотые')) {
      return [50.4484, 30.5134]; // Golden Gate
    }

    // Default to city center
    return [defaultLatitude, defaultLongitude];
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
    // For now, return a simple straight line
    // In production, you'd use Mapbox Directions API
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
      default:
        return 0xFF2196F3;
    }
  }
}
