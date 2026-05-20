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

  static void configure(ApiClient apiClient) {
    _instance = LocationClarificationService._internal(apiClient);
  }

  /// Sends the client's current GPS coordinates to the driver via
  /// POST /rides/{id}/client-location  { latitude, longitude }
  Future<bool> updateClientLocation({
    required String rideId,
    required String newLocation,
    String? additionalInstructions,
  }) async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        debugPrint('❌ Could not obtain GPS position for client-location update');
        return false;
      }

      final response = await _apiClient.post('/rides/$rideId/client-location', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      if (response.statusCode == 204 || response.statusCode == 200) {
        debugPrint('✅ Client location updated successfully');
        return true;
      }
      debugPrint('❌ Failed to update client location: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Error updating client location: $e');
      return false;
    }
  }
}
