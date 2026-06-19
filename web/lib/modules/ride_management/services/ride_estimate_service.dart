import 'dart:convert';
import '../models/ride_estimate.dart';
import '../models/vehicle_class.dart';
import '../../core/services/api_client.dart';

class RideEstimateRequest {
  final String fromAddress;
  final double? fromLat;
  final double? fromLng;
  final String toAddress;
  final double? toLat;
  final double? toLng;
  final VehicleClass vehicleClass;
  final bool isAirportTransfer;

  const RideEstimateRequest({
    required this.fromAddress,
    this.fromLat,
    this.fromLng,
    required this.toAddress,
    this.toLat,
    this.toLng,
    this.vehicleClass = VehicleClass.business,
    this.isAirportTransfer = false,
  });

  Map<String, dynamic> toJson() => {
    'from': {
      'address': fromAddress,
      if (fromLat != null) 'latitude': fromLat,
      if (fromLng != null) 'longitude': fromLng,
    },
    'to': {
      'address': toAddress,
      if (toLat != null) 'latitude': toLat,
      if (toLng != null) 'longitude': toLng,
    },
    'vehicleClass': vehicleClass.wire,
    'isAirportTransfer': isAirportTransfer,
  };
}

/// Service for the POST /rides/estimate endpoint.
///
/// Obtain via [context.read<AuthBloc>().apiClient] — never construct
/// [ApiClient] directly (that misses the auth token → 401).
class RideEstimateService {
  final ApiClient _apiClient;

  RideEstimateService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<RideEstimate?> estimate(RideEstimateRequest request) async {
    try {
      final response = await _apiClient.post(
        '/rides/estimate',
        request.toJson(),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return RideEstimate.fromJson(json);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
