import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'location_service.dart';

class LocationClarificationService {
  static LocationClarificationService? _instance;
  final ApiClient _apiClient;
  final LocationService _locationService = LocationService.instance;

  LocationClarificationService._internal(this._apiClient);

  static LocationClarificationService get instance {
    if (_instance == null) {
      throw StateError(
        'LocationClarificationService has not been configured. '
        'Call LocationClarificationService.configure() with an authenticated ApiClient first.'
      );
    }
    return _instance!;
  }

  /// Configure the singleton with an authenticated ApiClient
  static void configure(ApiClient apiClient) {
    _instance = LocationClarificationService._internal(apiClient);
  }

  Future<bool> updateClientLocation({
    required String rideId,
    required String newLocation,
    String? additionalInstructions,
  }) async {
    try {

      final position = await _locationService.getCurrentPosition();

      final response = await _apiClient.patch('/rides/$rideId/client-location', {
        'clientLocation': newLocation,
        'additionalInstructions': additionalInstructions,
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (response.statusCode == 200) {
        debugPrint('✅ Client location updated successfully');
        return true;
      } else {
        debugPrint('❌ Failed to update client location: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating client location: $e');
      return false;
    }
  }

  Future<bool> requestLocationClarification({
    required String rideId,
    String? message,
  }) async {
    try {
      final response = await _apiClient.post('/rides/$rideId/request-location', {
        'driverMessage': message ?? 'Driver requests to clarify your location',
        'timestamp': DateTime.now().toIso8601String(),
      });

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error requesting location clarification: $e');
      return false;
    }
  }

  Future<List<LocationUpdate>> getLocationUpdates(String rideId) async {
    try {
      final response = await _apiClient.get('/rides/$rideId/location-updates');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updates = data['updates'] as List;

        return updates
            .map((update) => LocationUpdate.fromJson(update))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error getting location updates: $e');
    }
    return [];
  }

  Future<bool> sendEmergencyLocation({
    required String rideId,
    required String emergencyMessage,
  }) async {
    try {
      final position = await _locationService.getCurrentPosition();

      final response = await _apiClient.post('/rides/$rideId/emergency-location', {
        'emergencyMessage': emergencyMessage,
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'priority': 'high',
      });

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error sending emergency location: $e');
      return false;
    }
  }

  Future<bool> shouldRequestLocationUpdate(String rideId) async {
    try {
      final response = await _apiClient.get('/rides/$rideId/location-status');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['needsUpdate'] ?? false;
      }
    } catch (e) {
      debugPrint('❌ Error checking location status: $e');
    }
    return false;
  }
}

class LocationUpdate {
  final String id;
  final String rideId;
  final String location;
  final String? additionalInstructions;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final LocationUpdateType type;
  final String? fromUser;

  LocationUpdate({
    required this.id,
    required this.rideId,
    required this.location,
    this.additionalInstructions,
    this.latitude,
    this.longitude,
    required this.timestamp,
    required this.type,
    this.fromUser,
  });

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      id: json['id'],
      rideId: json['rideId'],
      location: json['location'],
      additionalInstructions: json['additionalInstructions'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      type: LocationUpdateType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => LocationUpdateType.update,
      ),
      fromUser: json['fromUser'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rideId': rideId,
      'location': location,
      'additionalInstructions': additionalInstructions,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'fromUser': fromUser,
    };
  }

  String get iconName {
    switch (type) {
      case LocationUpdateType.initial:
        return 'location_on';
      case LocationUpdateType.update:
        return 'my_location';
      case LocationUpdateType.clarification:
        return 'help_outline';
      case LocationUpdateType.emergency:
        return 'emergency';
      case LocationUpdateType.arrival:
        return 'flag';
    }
  }

  String get colorName {
    switch (type) {
      case LocationUpdateType.initial:
        return 'blue';
      case LocationUpdateType.update:
        return 'green';
      case LocationUpdateType.clarification:
        return 'orange';
      case LocationUpdateType.emergency:
        return 'red';
      case LocationUpdateType.arrival:
        return 'purple';
    }
  }
}

enum LocationUpdateType {
  initial,
  update,
  clarification,
  emergency,
  arrival,
}