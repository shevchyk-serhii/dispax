import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../flight_management/models/airport_timing.dart';
import '../../core/services/api_client.dart';

class AirportTimingService {
  static AirportTimingService? _instance;
  final ApiClient _apiClient;

  AirportTimingService._internal(this._apiClient);

  static AirportTimingService get instance {
    if (_instance == null) {
      throw StateError(
        'AirportTimingService has not been configured. '
        'Call AirportTimingService.configure() with an authenticated ApiClient first.',
      );
    }
    return _instance!;
  }

  /// Configure the singleton with an authenticated ApiClient
  static void configure(ApiClient apiClient) {
    _instance = AirportTimingService._internal(apiClient);
  }

  Future<AirportTiming?> getOptimalEntryTime({
    required String rideId,
    required double driverLatitude,
    required double driverLongitude,
  }) async {
    try {
      debugPrint('🚗 Calculating optimal entry time for ride $rideId');

      final response = await _apiClient.post('/rides/$rideId/airport-timing', {
        'driverLatitude': driverLatitude,
        'driverLongitude': driverLongitude,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AirportTiming.fromJson(data);
      } else {
        debugPrint('❌ Failed to get airport timing: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error calculating airport timing: $e');
      return null;
    }
  }
}
