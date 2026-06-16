import 'dart:convert';
import '../models/person.dart';
import '../models/user_requests.dart';
import 'api_client.dart';

class UserService {
  final ApiClient privateApiClient;
  final bool _ownsClient;

  UserService({ApiClient? apiClient})
    : privateApiClient = apiClient ?? ApiClient(),
      _ownsClient = apiClient == null;

  Future<List<Person>> getClients() async {
    try {
      final response = await privateApiClient.get('/users/clients');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Person.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch clients: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error fetching clients: $e');
    }
  }

  Future<List<Person>> getDrivers() async {
    try {
      final response = await privateApiClient.get('/users/drivers');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Person.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch drivers: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error fetching drivers: $e');
    }
  }

  Future<Person> createClient(CreateUserRequest request) async {
    try {
      final response = await privateApiClient.post('/users', request.toJson());

      if (response.statusCode == 201) {
        return Person.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException('Failed to create client: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error creating client: $e');
    }
  }

  Future<Person> updateClient(String id, UpdateUserRequest request) async {
    try {
      final response = await privateApiClient.put(
        '/users/$id',
        request.toJson(),
      );

      if (response.statusCode == 200) {
        return Person.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException('Failed to update client: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error updating client: $e');
    }
  }

  Future<void> deactivateClient(String id) async {
    try {
      final response = await privateApiClient.delete('/users/$id');

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw ApiException(
          'Failed to deactivate client: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error deactivating client: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDriverStats() async {
    try {
      final response = await privateApiClient.get('/stats/drivers');

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        throw ApiException(
          'Failed to fetch driver stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error fetching driver stats: $e');
    }
  }

  void dispose() {
    if (_ownsClient) privateApiClient.dispose();
  }
}
