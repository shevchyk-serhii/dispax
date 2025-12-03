import 'dart:convert';
import '../models/ride.dart';
import '../models/person.dart';
import 'api_client.dart';

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

  Future<Ride?> getRideById(int id) async {
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

  Future<Ride> createRide(Ride ride) async {
    try {
      final response = await privateApiClient.post('/rides', ride.toJson());

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

  Future<Ride?> updateRide(int id, Ride ride) async {
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

  Future<bool> deleteRide(int id) async {
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

  void dispose() {
    privateApiClient.dispose();
  }
}
