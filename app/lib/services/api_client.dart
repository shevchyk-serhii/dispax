import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

class ApiClient {
  // Helper method to detect if running on physical device vs simulator
  static bool get isPhysicalDevice {
    if (Platform.isIOS) {
      // For iOS: check if it's running on simulator
      // Simulators typically have x86_64 or arm64 architecture but specific identifiers
      return !Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') &&
             !Platform.environment.containsKey('SIMULATOR_HOST_HOME');
    } else if (Platform.isAndroid) {
      // For Android: check various emulator indicators
      final fingerprint = Platform.environment['ANDROID_FINGERPRINT'] ?? '';
      final model = Platform.environment['ANDROID_MODEL'] ?? '';
      return !fingerprint.contains('generic') && 
             !model.contains('Emulator') &&
             !model.contains('google_sdk');
    }
    return false; // Default to simulator/emulator for other platforms
  }

  static String get privateBaseUrl {
    // Check for environment variable first
    const customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }

    // Check if we should use localhost for testing
    const useLocalhost = String.fromEnvironment('USE_LOCALHOST');
    if (useLocalhost == 'true') {
      return 'http://127.0.0.1:8080/api';
    }

    // Auto-detect based on platform and device type
    if (Platform.isAndroid) {
      if (isPhysicalDevice) {
        // Real Android device - use network IP
        return 'http://192.168.0.188:8080/api';
      } else {
        // Android emulator - use emulator special IP
        return 'http://10.0.2.2:8080/api';
      }
    } else if (Platform.isIOS) {
      if (isPhysicalDevice) {
        // Real iOS device - use network IP
        return 'http://192.168.0.188:8080/api';
      } else {
        // iOS simulator - use localhost
        return 'http://127.0.0.1:8080/api';
      }
    } else {
      return 'http://localhost:8080/api'; // Desktop/Web
    }
  }

  final http.Client privateClient;
  String? privateAuthToken;

  ApiClient({http.Client? client}) : privateClient = client ?? http.Client();

  void setAuthToken(String token) {
    privateAuthToken = token;
  }

  void clearAuthToken() {
    privateAuthToken = null;
  }

  Future<http.Response> get(String endpoint) async {
    try {
      var url = '$privateBaseUrl$endpoint';
      debugPrint('🌐 Making GET request to: $url');
      debugPrint('📱 Platform: ${Platform.operatingSystem}, Debug mode: $kDebugMode');
      debugPrint('📱 Physical device: $isPhysicalDevice');
      debugPrint('📱 Base URL: $privateBaseUrl');
      debugPrint('📋 Headers: $privateHeaders');
      
      final response = await privateClient
          .get(Uri.parse(url), headers: privateHeaders)
          .timeout(const Duration(seconds: 15));
      
      debugPrint('✅ Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}');
      return response;
    } on SocketException catch (e) {
      debugPrint('❌ SocketException: $e');
      throw ApiException(
        'Network error: Unable to connect to server at $privateBaseUrl. Make sure:\n'
        '1. Backend is running on your computer\n'
        '2. Your phone and computer are on the same WiFi network\n'
        '3. Firewall allows port 8080\n'
        'Error details: $e',
      );
    } on HttpException catch (e) {
      debugPrint('❌ HttpException: $e');
      throw ApiException('HTTP error: $e');
    } on FormatException catch (e) {
      debugPrint('❌ FormatException: $e');
      throw ApiException('Format error: $e');
    } catch (e) {
      debugPrint('❌ General Exception: $e');
      throw ApiException('Failed to perform GET request to $privateBaseUrl$endpoint: $e');
    }
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await privateClient.post(
        Uri.parse('$privateBaseUrl$endpoint'),
        headers: privateHeaders,
        body: jsonEncode(data),
      );
      return response;
    } catch (e) {
      throw ApiException('Failed to perform POST request: $e');
    }
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await privateClient.put(
        Uri.parse('$privateBaseUrl$endpoint'),
        headers: privateHeaders,
        body: jsonEncode(data),
      );
      return response;
    } catch (e) {
      throw ApiException('Failed to perform PUT request: $e');
    }
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await privateClient.patch(
        Uri.parse('$privateBaseUrl$endpoint'),
        headers: privateHeaders,
        body: jsonEncode(data),
      );
      return response;
    } catch (e) {
      throw ApiException('Failed to perform PATCH request: $e');
    }
  }

  Future<http.Response> delete(String endpoint) async {
    try {
      final response = await privateClient.delete(
        Uri.parse('$privateBaseUrl$endpoint'),
        headers: privateHeaders,
      );
      return response;
    } catch (e) {
      throw ApiException('Failed to perform DELETE request: $e');
    }
  }

  Map<String, String> get privateHeaders {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (privateAuthToken != null) {
      headers['Authorization'] = 'Bearer $privateAuthToken';
    }

    return headers;
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await privateClient
          .post(
            Uri.parse('$privateBaseUrl/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('Login response status: ${response.statusCode}');
      debugPrint('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        return null; // Invalid credentials
      } else {
        throw ApiException('Login failed with status: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw ApiException(
        'Network error: Unable to connect to server. Make sure the backend is running. Error: $e',
      );
    } catch (e) {
      throw ApiException('Login failed: $e');
    }
  }

  void dispose() {
    privateClient.close();
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
