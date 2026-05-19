import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../ride_management/models/ride.dart';
import '../models/location.dart' as app_location;

class MapboxService {
  static const String _accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  static String get accessToken {
    assert(_accessToken.isNotEmpty, 'MAPBOX_ACCESS_TOKEN must be set via --dart-define');
    return _accessToken;
  }

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
      debugPrint('MapboxService: MAPBOX_ACCESS_TOKEN not set, geocoding unavailable');
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
        final data = jsonDecode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final coordinates = features[0]['center'] as List;
          // Mapbox returns [longitude, latitude], we return [latitude, longitude]
          return [coordinates[1].toDouble(), coordinates[0].toDouble()];
        }
      } else {
        debugPrint('MapboxService: Geocoding failed with status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('MapboxService: Geocoding error: $e');
    }

    return null;
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

  static CircleAnnotationOptions createDriverMarker({
    required double latitude,
    required double longitude,
    String? driverId,
  }) {
    return CircleAnnotationOptions(
      geometry: Point(coordinates: Position(longitude, latitude)),
      circleRadius: 12.0,
      circleColor: _parseColor('blue'),
      circleStrokeWidth: 3.0,
      circleStrokeColor: 0xFFFFFFFF,
    );
  }

  static CircleAnnotationOptions createClientMarker({
    required double latitude,
    required double longitude,
  }) {
    return CircleAnnotationOptions(
      geometry: Point(coordinates: Position(longitude, latitude)),
      circleRadius: 10.0,
      circleColor: _parseColor('green'),
      circleStrokeWidth: 3.0,
      circleStrokeColor: 0xFFFFFFFF,
    );
  }

  static List<CircleAnnotationOptions> createRideMarkers({
    required app_location.Location from,
    required app_location.Location to,
  }) {
    final List<CircleAnnotationOptions> markers = [];

    if (from.latitude != null && from.longitude != null) {
      markers.add(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(from.longitude!, from.latitude!)),
        circleRadius: 8.0,
        circleColor: _parseColor('green'),
        circleStrokeWidth: 2.0,
        circleStrokeColor: 0xFFFFFFFF,
      ));
    }

    if (to.latitude != null && to.longitude != null) {
      markers.add(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(to.longitude!, to.latitude!)),
        circleRadius: 8.0,
        circleColor: _parseColor('red'),
        circleStrokeWidth: 2.0,
        circleStrokeColor: 0xFFFFFFFF,
      ));
    }

    return markers;
  }

  static CameraOptions getCameraForRoute({
    required app_location.Location from,
    required app_location.Location to,
    geo.Position? currentPosition,
  }) {
    final List<Position> positions = [];

    if (from.latitude != null && from.longitude != null) {
      positions.add(Position(from.longitude!, from.latitude!));
    }

    if (to.latitude != null && to.longitude != null) {
      positions.add(Position(to.longitude!, to.latitude!));
    }

    if (currentPosition != null) {
      positions.add(Position(currentPosition.longitude, currentPosition.latitude));
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

    double minLat = positions.map((p) => p.lat).reduce((a, b) => a < b ? a : b).toDouble();
    double maxLat = positions.map((p) => p.lat).reduce((a, b) => a > b ? a : b).toDouble();
    double minLng = positions.map((p) => p.lng).reduce((a, b) => a < b ? a : b).toDouble();
    double maxLng = positions.map((p) => p.lng).reduce((a, b) => a > b ? a : b).toDouble();

    double centerLat = (minLat + maxLat) / 2;
    double centerLng = (minLng + maxLng) / 2;

    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 15.0;
    if (maxDiff > 0.1) zoom = 10.0;
    else if (maxDiff > 0.05) zoom = 12.0;
    else if (maxDiff > 0.02) zoom = 13.0;
    else if (maxDiff > 0.01) zoom = 14.0;

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

    try {

    } catch (e) {
      developer.log('Error adding marker images: $e', name: 'MapboxService');
    }
  }
}