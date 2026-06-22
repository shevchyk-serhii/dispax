import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/ride.dart';
import '../models/create_ride_request.dart';
import '../models/driver_earnings.dart';
import '../../core/models/person.dart';
import '../../core/services/api_client.dart';

class RideService {
  final ApiClient privateApiClient;
  final bool _ownsClient;

  RideService({ApiClient? apiClient})
    : privateApiClient = apiClient ?? ApiClient(),
      _ownsClient = apiClient == null;

  Future<List<Ride>> getAllRides() async {
    try {
      final response = await privateApiClient.get('/rides');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Ride.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch rides: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error fetching rides: $e');
    }
  }

  Future<List<Ride>> getRidesForUser(Person user) async {
    try {
      final String endpoint;
      switch (user.role) {
        case PersonRole.driver:
          endpoint = '/rides/driver/${user.id}';
        case PersonRole.client:
          endpoint = '/rides/client/${user.id}';
        default:
          endpoint = '/rides';
      }

      final response = await privateApiClient.get(endpoint);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Ride.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch user rides: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error fetching user rides: $e');
    }
  }

  /// Driver earnings for a period ('day' | 'week' | 'month'), anchored to [date].
  Future<DriverEarnings> getDriverEarnings(
    String driverId,
    String period,
    DateTime date,
  ) async {
    try {
      final d =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final response = await privateApiClient.get(
        '/drivers/$driverId/earnings?period=$period&date=$d',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return DriverEarnings.fromJson(json);
      } else {
        throw ApiException(
          'Failed to fetch driver earnings: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is UnauthorizedException) rethrow;
      throw ApiException('Error fetching driver earnings: $e');
    }
  }

  Future<Ride?> getRideById(String id) async {
    try {
      final response = await privateApiClient.get('/rides/$id');

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Ride.fromJson(json);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiException('Failed to fetch ride: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error fetching ride: $e');
    }
  }

  Future<Ride> createRide(CreateRideRequest request) async {
    try {
      final response = await privateApiClient.post('/rides', request.toJson());

      if (response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Ride.fromJson(json);
      } else {
        throw ApiException.fromResponse(response, 'Failed to create ride');
      }
    } on ApiException {
      // Already carries the server's message (e.g. a 400 validation error);
      // don't re-wrap it into an opaque "Error creating ride: ApiException: ..."
      rethrow;
    } catch (e) {
      throw ApiException('Error creating ride: $e');
    }
  }

  Future<Ride?> updateRide(String id, Ride ride) async {
    try {
      final response = await privateApiClient.put('/rides/$id', ride.toJson());

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Ride.fromJson(json);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiException('Failed to update ride: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error updating ride: $e');
    }
  }

  Future<bool> updateRideStatus(String id, RideStatus status) async {
    try {
      final response = await privateApiClient.put('/rides/$id/status', {
        'status': status.value,
      });

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        return false;
      } else {
        throw ApiException(
          'Failed to update ride status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error updating ride status: $e');
    }
  }

  Future<List<Ride>> getClientRides(String clientId) async {
    try {
      final response = await privateApiClient.get('/rides/client/$clientId');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Ride.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch client rides: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error fetching client rides: $e');
    }
  }

  Future<List<Ride>> getPendingRides() async {
    try {
      final response = await privateApiClient.get('/rides/pending');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Ride.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch pending rides: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error fetching pending rides: $e');
    }
  }

  Future<Ride> assignDriver(
    String rideId,
    String driverId, {
    bool overrideScheduleConflict = false,
  }) async {
    final response = await privateApiClient.put(
      '/rides/$rideId/assign-driver',
      {
        'driverId': driverId,
        'overrideScheduleConflict': overrideScheduleConflict,
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      return Ride.fromJson(json);
    }
    // Surface the backend's `{"error": ...}` message (and status code) instead
    // of a bare "400", so the UI can show the real reason and react to conflicts.
    throw ApiException.fromResponse(response, 'Failed to assign driver');
  }

  Future<Ride> reassignDriver(
    String rideId,
    String newDriverId, {
    bool overrideScheduleConflict = false,
  }) async {
    final response = await privateApiClient
        .put('/rides/$rideId/reassign-driver', {
          'driverId': newDriverId,
          'overrideScheduleConflict': overrideScheduleConflict,
        });

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      return Ride.fromJson(json);
    }
    throw ApiException.fromResponse(response, 'Failed to reassign driver');
  }

  Future<void> updateDriverLocation(
    String driverId,
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await privateApiClient.put(
        '/drivers/$driverId/location',
        {'latitude': latitude, 'longitude': longitude},
      );
      debugPrint(
        '📍 Location update: ${response.statusCode} ($latitude, $longitude)',
      );
    } catch (e) {
      debugPrint('📍 Location update failed: $e');
    }
  }

  Future<Map<String, dynamic>?> getDriverProximity(String rideId) async {
    try {
      final response = await privateApiClient.get(
        '/rides/$rideId/driver-location',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateClientLocation(
    String rideId,
    double latitude,
    double longitude,
  ) async {
    try {
      await privateApiClient.post('/rides/$rideId/client-location', {
        'latitude': latitude,
        'longitude': longitude,
      });
    } catch (e) {
      // Best-effort location update
    }
  }

  Future<void> cancelRide(String id, String reason, {double? fee}) async {
    try {
      final body = <String, dynamic>{'reason': reason};
      if (fee != null) body['fee'] = fee;
      final response = await privateApiClient.put('/rides/$id/cancel', body);
      if (response.statusCode != 200) {
        throw ApiException('Failed to cancel ride: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error cancelling ride: $e');
    }
  }

  Future<void> markAirportCheckpoint(String rideId, String checkpoint) async {
    try {
      final response = await privateApiClient.post(
        '/rides/$rideId/airport-checkpoint',
        {'checkpoint': checkpoint},
      );
      if (response.statusCode != 204) {
        throw ApiException('Failed to mark checkpoint: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error marking airport checkpoint: $e');
    }
  }

  Future<Map<String, dynamic>?> getAirportCheckpoint(String rideId) async {
    try {
      final response = await privateApiClient.get(
        '/rides/$rideId/airport-checkpoint',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    if (_ownsClient) privateApiClient.dispose();
  }
}
