import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class TestDataService {
  static const String baseUrl = AppConstants.baseUrl;

  /// Seeds the database with test data (debug only)
  static Future<bool> seedTestData() async {
    if (!kDebugMode) return false;
    try {
      developer.log('Seeding database with test data...', name: 'TestDataService');

      final response = await http.post(
        Uri.parse('$baseUrl/api/test/seed'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        developer.log('Test data seeded successfully: ${data['message']}', name: 'TestDataService');
        developer.log('Users created: ${data['users_created']}', name: 'TestDataService');
        developer.log('Rides created: ${data['rides_created']}', name: 'TestDataService');
        return true;
      } else {
        developer.log('Failed to seed test data: ${response.statusCode}', name: 'TestDataService');
        developer.log('Response: ${response.body}', name: 'TestDataService');
        return false;
      }
    } catch (e) {
      developer.log('Error seeding test data: $e', name: 'TestDataService');
      return false;
    }
  }

  /// Gets the current test data status
  static Future<Map<String, dynamic>?> getTestDataStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/test/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        developer.log('Failed to get test data status: ${response.statusCode}', name: 'TestDataService');
        return null;
      }
    } catch (e) {
      developer.log('Error getting test data status: $e', name: 'TestDataService');
      return null;
    }
  }

  /// Clears all test data from the database (debug only)
  static Future<bool> clearTestData() async {
    if (!kDebugMode) return false;
    try {
      developer.log('Clearing test data...', name: 'TestDataService');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/test/clear'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        developer.log('Test data cleared successfully', name: 'TestDataService');
        return true;
      } else {
        developer.log('Failed to clear test data: ${response.statusCode}', name: 'TestDataService');
        return false;
      }
    } catch (e) {
      developer.log('Error clearing test data: $e', name: 'TestDataService');
      return false;
    }
  }

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
