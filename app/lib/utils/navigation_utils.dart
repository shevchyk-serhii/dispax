import 'package:url_launcher/url_launcher.dart';
import '../models/location.dart';

class NavigationUtils {
  /// Открывает Google Maps с построением маршрута от текущего местоположения к destination
  static Future<void> openGoogleMapsNavigation(Location destination) async {
    final destinationAddress = Uri.encodeComponent(destination.address);
    
    // URL для Google Maps с навигацией
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destinationAddress&travelmode=driving';
    
    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      // Fallback: попробовать открыть через app scheme
      await _tryGoogleMapsApp(destination);
    }
  }

  /// Открывает Google Maps с маршрутом от origin к destination
  static Future<void> openGoogleMapsRoute(Location origin, Location destination) async {
    final originAddress = Uri.encodeComponent(origin.address);
    final destinationAddress = Uri.encodeComponent(destination.address);
    
    // URL для Google Maps с указанием точек отправления и назначения
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$originAddress&destination=$destinationAddress&travelmode=driving';
    
    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      // Fallback: попробовать открыть через app scheme
      await _tryGoogleMapsAppWithRoute(origin, destination);
    }
  }

  /// Попытка открыть Google Maps приложение через app scheme
  static Future<void> _tryGoogleMapsApp(Location destination) async {
    final destinationAddress = Uri.encodeComponent(destination.address);
    
    // Google Maps app scheme
    final appUrl = 'comgooglemaps://?daddr=$destinationAddress&directionsmode=driving';
    
    try {
      final Uri uri = Uri.parse(appUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Google Maps app not found';
      }
    } catch (e) {
      throw 'Could not open navigation: $e';
    }
  }

  /// Попытка открыть Google Maps приложение с маршрутом через app scheme
  static Future<void> _tryGoogleMapsAppWithRoute(Location origin, Location destination) async {
    final originAddress = Uri.encodeComponent(origin.address);
    final destinationAddress = Uri.encodeComponent(destination.address);
    
    // Google Maps app scheme with origin and destination
    final appUrl = 'comgooglemaps://?saddr=$originAddress&daddr=$destinationAddress&directionsmode=driving';
    
    try {
      final Uri uri = Uri.parse(appUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Google Maps app not found';
      }
    } catch (e) {
      throw 'Could not open navigation: $e';
    }
  }

  /// Открывает карту с указанием конкретной точки
  static Future<void> openGoogleMapsLocation(Location location) async {
    final address = Uri.encodeComponent(location.address);
    
    String googleMapsUrl;
    if (location.latitude != null && location.longitude != null) {
      // Если есть координаты, используем их для более точного позиционирования
      googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
    } else {
      // Используем адрес
      googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$address';
    }
    
    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      throw 'Could not open location: $e';
    }
  }
}