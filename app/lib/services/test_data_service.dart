import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class TestDataService {
  static const String baseUrl = AppConstants.baseUrl;

  /// Seed the database with test data
  static Future<bool> seedTestData() async {
    try {
      print('🌱 Seeding database with test data...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/test/seed'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Test data seeded successfully: ${data['message']}');
        print('   Users created: ${data['users_created']}');
        print('   Rides created: ${data['rides_created']}');
        return true;
      } else {
        print('❌ Failed to seed test data: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error seeding test data: $e');
      return false;
    }
  }

  /// Get test data status
  static Future<Map<String, dynamic>?> getTestDataStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/test/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to get test data status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting test data status: $e');
      return null;
    }
  }

  /// Clear all test data
  static Future<bool> clearTestData() async {
    try {
      print('🗑️ Clearing test data...');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/api/test/clear'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('✅ Test data cleared successfully');
        return true;
      } else {
        print('❌ Failed to clear test data: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error clearing test data: $e');
      return false;
    }
  }

  /// Check if server is available
  static Future<bool> isServerAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Server not available: $e');
      return false;
    }
  }
}