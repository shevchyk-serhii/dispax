import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/muc_flight.dart';
import '../../core/services/api_client.dart';

/// Fetches the MUC arrivals board for the dispatcher (GET /api/flights/arrivals).
class ArrivalsBoardService {
  static ArrivalsBoardService? _instance;
  final ApiClient _apiClient;

  ArrivalsBoardService._internal(this._apiClient);

  static ArrivalsBoardService get instance {
    if (_instance == null) {
      throw StateError(
        'ArrivalsBoardService has not been configured. '
        'Call ArrivalsBoardService.configure() with an authenticated ApiClient first.',
      );
    }
    return _instance!;
  }

  static void configure(ApiClient apiClient) {
    _instance = ArrivalsBoardService._internal(apiClient);
  }

  /// Today's arrivals (or [date] when given, ISO yyyy-MM-dd). Returns [] on failure.
  Future<List<MucFlight>> getArrivals({String? date}) async {
    try {
      final path = date == null
          ? '/flights/arrivals'
          : '/flights/arrivals?date=$date';
      final response = await _apiClient.get(path);
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((e) => MucFlight.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('❌ arrivals board failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('❌ arrivals board error: $e');
      return [];
    }
  }
}
