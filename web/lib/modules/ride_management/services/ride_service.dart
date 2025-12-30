import 'dart:convert';
import '../models/ride.dart';
import '../models/create_ride_request.dart';
import '../../core/models/person.dart';
import '../../core/services/api_client.dart';

class RideService {
  final ApiClient privateApiClient;

  RideService({ApiClient? apiClient})
    : privateApiClient = apiClient ?? ApiClient();

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
      final response = await privateApiClient.get('/rides');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final rides = jsonList.map((json) => Ride.fromJson(json)).toList();
        return rides;
      } else {
        throw ApiException(
          'Failed to fetch user rides: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error fetching user rides: $e');
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
        throw ApiException('Failed to create ride: ${response.statusCode}');
      }
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

  Future<bool> deleteRide(String id) async {
    try {
      final response = await privateApiClient.delete('/rides/$id');

      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 404) {
        return false;
      } else {
        throw ApiException('Failed to delete ride: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error deleting ride: $e');
    }
  }

  Future<bool> updateRideStatus(String id, RideStatus status) async {
    try {
      final response = await privateApiClient.patch('/rides/$id/status', {
        'status': status.value,
      });

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        return false;
      } else {
        throw ApiException('Failed to update ride status: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error updating ride status: $e');
    }
  }

  Future<Ride> assignDriver(String rideId, String driverId) async {
    try {
      final response = await privateApiClient.put('/rides/$rideId/assign-driver', {
        'driverId': driverId,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Ride.fromJson(json);
      } else {
        throw ApiException('Failed to assign driver: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error assigning driver: $e');
    }
  }

  void dispose() {
    privateApiClient.dispose();
  }
}
