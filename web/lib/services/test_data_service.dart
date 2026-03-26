import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class TestDataService {
  static const String baseUrl = AppConstants.baseUrl;

  /// Checks if the server is available
  static Future<bool> isServerAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      developer.log('Server not available: $e', name: 'TestDataService');
      return false;
    }
  }
}
