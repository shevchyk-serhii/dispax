import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/location.dart';

class LocationService {
  static LocationService? _instance;
  LocationService._internal();
  
  static LocationService get instance {
    _instance ??= LocationService._internal();
    return _instance!;
  }

  StreamController<geo.Position>? _positionController;
  StreamSubscription<geo.Position>? _positionSubscription;
  geo.Position? _currentPosition;

  // Stream для текущего местоположения пользователя
  Stream<geo.Position> get positionStream {
    _positionController ??= StreamController<geo.Position>.broadcast();
    return _positionController!.stream;
  }

  geo.Position? get currentPosition => _currentPosition;

  /// Проверяет и запрашивает разрешения на геолокацию
  Future<bool> checkAndRequestLocationPermission() async {
    bool serviceEnabled;
    geo.LocationPermission permission;

    // Проверяем, включена ли служба геолокации
    serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return false;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Получает текущее местоположение один раз
  Future<geo.Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestLocationPermission();
      if (!hasPermission) return null;

      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      
      _currentPosition = position;
      return position;
    } catch (e) {
      // В продакшене здесь должен быть logger
      // debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Начинает отслеживание местоположения в реальном времени
  Future<bool> startLocationTracking() async {
    try {
      final hasPermission = await checkAndRequestLocationPermission();
      if (!hasPermission) return false;

      // Останавливаем предыдущее отслеживание если оно есть
      await stopLocationTracking();

      _positionController ??= StreamController<geo.Position>.broadcast();

      const geo.LocationSettings locationSettings = geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10, // Обновлять при изменении на 10+ метров
      );

      _positionSubscription = geo.Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (geo.Position position) {
          _currentPosition = position;
          _positionController?.add(position);
        },
        onError: (error) {
          // В продакшене здесь должен быть logger
          // debugPrint('Location tracking error: $error');
        },
      );

      return true;
    } catch (e) {
      // В продакшене здесь должен быть logger
      // debugPrint('Error starting location tracking: $e');
      return false;
    }
  }

  /// Останавливает отслеживание местоположения
  Future<void> stopLocationTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Вычисляет расстояние между двумя точками в метрах
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return geo.Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Конвертирует Position в модель Location
  Location positionToLocation(geo.Position position) {
    return Location(
      latitude: position.latitude,
      longitude: position.longitude,
      address: '', // Адрес можно получить через reverse geocoding
    );
  }

  /// Очищает ресурсы
  void dispose() {
    stopLocationTracking();
    _positionController?.close();
    _positionController = null;
  }
}