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
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'ArrivalsBoardService has not been configured. '
        'Call ArrivalsBoardService.configure() with an authenticated ApiClient first.',
      );
    }
    return instance;
  }

  static void configure(ApiClient apiClient) {
    _instance = ArrivalsBoardService._internal(apiClient);
  }

  /// A single flight WITH its gate (the board view has no gate — it lives on the flight's
  /// detail page). Backed by GET /api/flights/lookup. Returns null when not found / on failure.
  Future<MucFlight?> lookupFlight({
    required String flightNumber,
    String? date,
    bool isArrival = true,
  }) async {
    try {
      final params = <String>[
        'flightNumber=${Uri.encodeQueryComponent(flightNumber)}',
        'isArrival=$isArrival',
        if (date != null) 'date=$date',
      ];
      final response = await _apiClient.get(
        '/flights/lookup?${params.join('&')}',
      );
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body == 'null') return null;
        return MucFlight.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      debugPrint('❌ flight lookup failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ flight lookup error: $e');
      return null;
    }
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
