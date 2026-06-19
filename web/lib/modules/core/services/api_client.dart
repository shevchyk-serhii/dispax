import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../constants/app_constants.dart';

class UnauthorizedException extends ApiException {
  UnauthorizedException() : super('Unauthorized: session expired');
}

class ApiClient {
  VoidCallback? onUnauthorized;

  static String get wsBaseUrl {
    final base = _defaultBaseUrl.replaceFirst('/api', '');
    return base
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
  }

  static String get _defaultBaseUrl {
    const customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }

    const useLocalhost = String.fromEnvironment('USE_LOCALHOST');
    if (useLocalhost == 'true') {
      return 'http://127.0.0.1:8080/api';
    }

    return '${AppConstants.baseUrl}/api';
  }

  final http.Client privateClient;
  final String _baseUrl;
  String? privateAuthToken;

  ApiClient({http.Client? client, String? baseUrl})
    : privateClient = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  void setAuthToken(String token) {
    privateAuthToken = token;
  }

  void clearAuthToken() {
    privateAuthToken = null;
  }

  static http.Response _utf8Response(http.Response r) => http.Response.bytes(
    r.bodyBytes,
    r.statusCode,
    headers: {'content-type': 'application/json; charset=utf-8', ...r.headers},
    request: r.request,
    isRedirect: r.isRedirect,
    persistentConnection: r.persistentConnection,
    reasonPhrase: r.reasonPhrase,
  );

  Future<http.Response> get(String endpoint, {String? acceptOverride}) async {
    try {
      var url = '$_baseUrl$endpoint';
      debugPrint('🌐 GET $endpoint');

      final headers = acceptOverride == null
          ? privateHeaders
          : (Map<String, String>.from(privateHeaders)
              ..['Accept'] = acceptOverride);

      final raw = await privateClient
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      final response = _utf8Response(raw);

      debugPrint('✅ Response status: ${response.statusCode}');
      debugPrint(
        '📄 Response body: ${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}',
      );
      if (response.statusCode == 401) _handleUnauthorized();
      return response;
    } on UnauthorizedException {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('❌ SocketException: $e');
      throw ApiException(_networkErrorMessage(e));
    } on HttpException catch (e) {
      debugPrint('❌ HttpException: $e');
      throw ApiException('HTTP error: $e');
    } on FormatException catch (e) {
      debugPrint('❌ FormatException: $e');
      throw ApiException('Format error: $e');
    } catch (e) {
      debugPrint('❌ General Exception: $e');
      throw ApiException(
        'Failed to perform GET request to $_baseUrl$endpoint: $e',
      );
    }
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = _utf8Response(
        await privateClient
            .post(
              Uri.parse('$_baseUrl$endpoint'),
              headers: privateHeaders,
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 15)),
      );
      if (response.statusCode == 401) _handleUnauthorized();
      return response;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to perform POST request: $e');
    }
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = _utf8Response(
        await privateClient
            .put(
              Uri.parse('$_baseUrl$endpoint'),
              headers: privateHeaders,
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 15)),
      );
      if (response.statusCode == 401) _handleUnauthorized();
      return response;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to perform PUT request: $e');
    }
  }

  Future<http.Response> patch(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = _utf8Response(
        await privateClient
            .patch(
              Uri.parse('$_baseUrl$endpoint'),
              headers: privateHeaders,
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 15)),
      );
      if (response.statusCode == 401) _handleUnauthorized();
      return response;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to perform PATCH request: $e');
    }
  }

  Future<http.Response> delete(String endpoint) async {
    try {
      final response = _utf8Response(
        await privateClient
            .delete(Uri.parse('$_baseUrl$endpoint'), headers: privateHeaders)
            .timeout(const Duration(seconds: 15)),
      );
      if (response.statusCode == 401) _handleUnauthorized();
      return response;
    } on UnauthorizedException {
      rethrow;
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
            Uri.parse('$_baseUrl/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        return null;
      } else {
        throw ApiException('Login failed with status: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('❌ SocketException (login): $e');
      throw ApiException(_networkErrorMessage(e));
    } catch (e) {
      throw ApiException('Login failed: $e');
    }
  }

  /// Upload a file as multipart/form-data with Bearer authentication.
  /// Used for profile avatar upload.
  Future<http.Response> postMultipart(
    String endpoint,
    String fieldName,
    Uint8List bytes,
    String contentType,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);
      if (privateAuthToken != null) {
        request.headers['Authorization'] = 'Bearer $privateAuthToken';
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: 'avatar',
          contentType: MediaType.parse(contentType),
        ),
      );
      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401) _handleUnauthorized();
      return response;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to upload file: $e');
    }
  }

  /// Fetch raw bytes from an authenticated endpoint.
  /// Used for profile avatar retrieval (GET /users/{id}/avatar requires Bearer).
  /// Returns null for 404 (no avatar / not found) so callers can fall back to initials.
  Future<Uint8List?> getBytes(String endpoint) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await privateClient
          .get(uri, headers: privateHeaders)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        _handleUnauthorized();
        return null;
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw ApiException(
          'getBytes failed with status ${response.statusCode}: ${response.body}',
        );
      }
      return response.bodyBytes;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to fetch bytes from $_baseUrl$endpoint: $e');
    }
  }

  void _handleUnauthorized() {
    onUnauthorized?.call();
    throw UnauthorizedException();
  }

  /// Builds a user-facing message for a failed network connection.
  ///
  /// In release builds we never surface the raw socket error, the server URL,
  /// or local-development hints (backend/WiFi/firewall) — that leaks internal
  /// infrastructure and confuses real users. In debug builds we keep the full
  /// diagnostics, since they're invaluable when running against a local backend.
  String _networkErrorMessage(Object error) {
    if (kDebugMode) {
      return 'Network error: Unable to connect to server at $_baseUrl. Make sure:\n'
          '1. Backend is running on your computer\n'
          '2. Your phone and computer are on the same WiFi network\n'
          '3. Firewall allows port 8080\n'
          'Error details: $error';
    }
    return 'Unable to reach the server. Please check your internet connection '
        'and try again.';
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
