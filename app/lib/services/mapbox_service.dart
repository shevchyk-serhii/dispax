import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/ride.dart';
import '../models/location.dart' as app_location;

class MapboxService {
  static const String _accessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';

  // You'll need to set your Mapbox access token
  // Get it from https://account.mapbox.com/access-tokens/
  // For development, you can disable telemetry to avoid warnings
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
      case 'purple':
        return 0xFF9C27B0;
      default:
        return 0xFF2196F3;
    }
  }

  // Создает маркер для водителя (используем CircleAnnotation пока не настроим изображения)
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

  // Создает маркер для клиента (используем CircleAnnotation пока не настроим изображения)
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

  // Создает маркеры для начала и конца поездки
  static List<CircleAnnotationOptions> createRideMarkers({
    required app_location.Location from,
    required app_location.Location to,
  }) {
    final List<CircleAnnotationOptions> markers = [];
    
    // Маркер начальной точки (зеленый)
    if (from.latitude != null && from.longitude != null) {
      markers.add(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(from.longitude!, from.latitude!)),
        circleRadius: 8.0,
        circleColor: _parseColor('green'),
        circleStrokeWidth: 2.0,
        circleStrokeColor: 0xFFFFFFFF,
      ));
    }
    
    // Маркер конечной точки (красный)
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

  // Получает оптимальный zoom и центр для отображения маршрута
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
    
    // Вычисляем границы для всех точек
    double minLat = positions.map((p) => p.lat).reduce((a, b) => a < b ? a : b).toDouble();
    double maxLat = positions.map((p) => p.lat).reduce((a, b) => a > b ? a : b).toDouble();
    double minLng = positions.map((p) => p.lng).reduce((a, b) => a < b ? a : b).toDouble();
    double maxLng = positions.map((p) => p.lng).reduce((a, b) => a > b ? a : b).toDouble();
    
    // Центр
    double centerLat = (minLat + maxLat) / 2;
    double centerLng = (minLng + maxLng) / 2;
    
    // Примерный расчет zoom level
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

  // Проверяет, находится ли поездка в процессе
  static bool isRideInProgress(Ride ride) {
    return ride.status == RideStatus.assigned || 
           ride.status == RideStatus.inProgress;
  }

  // Добавляет стандартные изображения маркеров
  static Future<void> addDefaultImages(MapboxMap mapboxMap) async {
    // In real app, this would send location to server
    // Пока оставим заглушки для будущей реализации
    try {
      // await mapboxMap.style.addImage('driver-marker', driverMarkerBytes);
      // await mapboxMap.style.addImage('client-marker', clientMarkerBytes);
      // await mapboxMap.style.addImage('pickup-marker', pickupMarkerBytes);
      // await mapboxMap.style.addImage('destination-marker', destinationMarkerBytes);
    } catch (e) {
      print('Error adding marker images: $e');
    }
  }
}
