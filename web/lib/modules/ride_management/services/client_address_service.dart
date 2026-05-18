import 'dart:convert';
import '../models/client_address.dart';
import '../../core/services/api_client.dart';

class ClientAddressService {
  final ApiClient _apiClient;
  final bool _ownsClient;

  ClientAddressService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        _ownsClient = apiClient == null;

  Future<List<ClientAddress>> getAddresses(String clientId) async {
    final response = await _apiClient.get('/api/clients/$clientId/addresses');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      return list.map((e) => ClientAddress.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<ClientAddress?> saveAddress({
    required String clientId,
    required String label,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{
      'label': label,
      'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    final response = await _apiClient.post('/api/clients/$clientId/addresses', body);
    if (response.statusCode == 201) {
      return ClientAddress.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    return null;
  }

  Future<bool> deleteAddress(String clientId, String addressId) async {
    final response = await _apiClient.delete('/api/clients/$clientId/addresses/$addressId');
    return response.statusCode == 204;
  }

  void dispose() {
    if (_ownsClient) _apiClient.dispose();
  }
}
