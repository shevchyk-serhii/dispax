import 'dart:convert';
import '../../core/services/api_client.dart';

/// Thin wrapper over the driver availability endpoints, shared by the
/// availability toggle and the Today-screen availability pill so the
/// load/update logic lives in one place (not duplicated per widget).
class DriverAvailabilityService {
  final ApiClient _apiClient;

  const DriverAvailabilityService(this._apiClient);

  /// Returns true when the driver is currently "Available". Any error or
  /// non-200 response resolves to false (offline) rather than throwing.
  Future<bool> isAvailable(String driverId) async {
    try {
      final response = await _apiClient.get('/drivers/$driverId/availability');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['status'] == 'Available';
      }
    } catch (_) {
      // Default to offline on any failure.
    }
    return false;
  }

  /// Sets availability. Returns true on a successful (200) update; throws on
  /// transport errors so the caller can surface a message.
  Future<bool> setAvailable(String driverId, bool available) async {
    final response = await _apiClient.put('/drivers/$driverId/availability', {
      'status': available ? 'Available' : 'Offline',
    });
    return response.statusCode == 200;
  }
}
