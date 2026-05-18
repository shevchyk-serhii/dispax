import 'dart:convert';
import '../../core/services/api_client.dart';
import '../models/client_company.dart';

class ClientCompanyService {
  final ApiClient _apiClient;
  final bool _ownsClient;

  ClientCompanyService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        _ownsClient = apiClient == null;

  Future<List<ClientCompany>> getCompanies() async {
    final response = await _apiClient.get('/billing/companies');
    if (response.statusCode == 200) {
      final List<dynamic> json = jsonDecode(response.body);
      return json.map((e) => ClientCompany.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException('Failed to fetch client companies: ${response.statusCode}');
  }

  Future<ClientCompany> createCompany(CreateClientCompanyRequest req) async {
    final response = await _apiClient.post('/billing/companies', req.toJson());
    if (response.statusCode == 201) {
      return ClientCompany.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException('Failed to create company: ${response.statusCode}');
  }

  Future<ClientCompany?> updateCompany(String id, CreateClientCompanyRequest req) async {
    final response = await _apiClient.put('/billing/companies/$id', req.toJson());
    if (response.statusCode == 200) {
      return ClientCompany.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    if (response.statusCode == 404) return null;
    throw ApiException('Failed to update company: ${response.statusCode}');
  }

  Future<bool> deleteCompany(String id) async {
    final response = await _apiClient.delete('/billing/companies/$id');
    if (response.statusCode == 204) return true;
    if (response.statusCode == 404) return false;
    throw ApiException('Failed to delete company: ${response.statusCode}');
  }

  void dispose() {
    if (_ownsClient) _apiClient.dispose();
  }
}
