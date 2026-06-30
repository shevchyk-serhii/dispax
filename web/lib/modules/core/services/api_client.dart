import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../constants/app_constants.dart';

class UnauthorizedException extends ApiException {
  UnauthorizedException() : super('Unauthorized: session expired');

  @override
  AppErrorKind get kind => AppErrorKind.unauthorized;
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
    } on TimeoutException catch (e) {
      debugPrint('❌ TimeoutException: $e');
      throw ApiException(_networkErrorMessage(e), cause: e);
    } on SocketException catch (e) {
      debugPrint('❌ SocketException: $e');
      throw ApiException(_networkErrorMessage(e), cause: e);
    } on HttpException catch (e) {
      debugPrint('❌ HttpException: $e');
      throw ApiException('HTTP error: $e', cause: e);
    } on FormatException catch (e) {
      debugPrint('❌ FormatException: $e');
      throw ApiException('Format error: $e', cause: e);
    } catch (e) {
      debugPrint('❌ General Exception: $e');
      throw ApiException(
        'Failed to perform GET request to $_baseUrl$endpoint: $e',
        cause: e,
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
    } on TimeoutException catch (e) {
      throw ApiException(_networkErrorMessage(e), cause: e);
    } on SocketException catch (e) {
      throw ApiException(_networkErrorMessage(e), cause: e);
    } catch (e) {
      throw ApiException('Failed to perform POST request: $e', cause: e);
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
    } on TimeoutException catch (e) {
      throw ApiException(_networkErrorMessage(e), cause: e);
    } on SocketException catch (e) {
      throw ApiException(_networkErrorMessage(e), cause: e);
    } catch (e) {
      throw ApiException('Failed to perform PUT request: $e', cause: e);
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
    } on TimeoutException catch (e) {
      throw ApiException(_networkErrorMessage(e), cause: e);
    } on SocketException catch (e) {
      throw ApiException(_networkErrorMessage(e), cause: e);
    } catch (e) {
      throw ApiException('Failed to perform PATCH request: $e', cause: e);
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
    } on TimeoutException catch (e) {
      throw ApiException(_networkErrorMessage(e), cause: e);
    } on SocketException catch (e) {
      throw ApiException(_networkErrorMessage(e), cause: e);
    } catch (e) {
      throw ApiException('Failed to perform DELETE request: $e', cause: e);
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
    } on TimeoutException catch (e) {
      debugPrint('❌ TimeoutException (login): $e');
      throw ApiException(_networkErrorMessage(e), cause: e);
    } on SocketException catch (e) {
      debugPrint('❌ SocketException (login): $e');
      throw ApiException(_networkErrorMessage(e), cause: e);
    } catch (e) {
      throw ApiException('Login failed: $e', cause: e);
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
    } on TimeoutException catch (e) {
      throw ApiException(_networkErrorMessage(e), cause: e);
    } on SocketException catch (e) {
      throw ApiException(_networkErrorMessage(e), cause: e);
    } catch (e) {
      throw ApiException('Failed to upload file: $e', cause: e);
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
      throw ApiException(
        'Failed to fetch bytes from $_baseUrl$endpoint: $e',
        cause: e,
      );
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

/// Coarse classification of a failure, derived from the HTTP status code or the
/// underlying cause. The UI maps this to a short, localized, non-technical
/// message (see `friendlyError` in `error_messages.dart`) instead of surfacing
/// the raw [ApiException.message], which may contain the backend URL, the
/// exception class name, or a stack-trace-like tail.
enum AppErrorKind {
  network,
  timeout,
  unauthorized,
  notFound,
  conflict,
  validation,
  server,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// The original lower-level error this exception wrapped (e.g. a
  /// [TimeoutException] or [SocketException]), when known. Carried so [kind]
  /// can classify network/timeout failures — for which [statusCode] is null and
  /// [message] is just a wrapped string — without re-parsing the message text.
  final Object? cause;

  /// Structured schedule-conflict details from the backend (see ApiError
  /// .scheduleConflict on the server): the conflicting ride's id, client, route
  /// and pickup time. Present only on an assign/reassign schedule conflict, so
  /// the UI can render a localized, human-readable dialog instead of the raw
  /// fallback [message]. Null for every other error.
  final ScheduleConflictInfo? scheduleConflict;

  ApiException(
    this.message, {
    this.statusCode,
    this.cause,
    this.scheduleConflict,
  });

  /// Classifies this failure for the UI. Status code wins when present;
  /// otherwise the wrapped [cause] (or the message, as a last resort) is used to
  /// tell a timeout from a generic network drop. Never surfaces the raw text.
  AppErrorKind get kind {
    final code = statusCode;
    if (code != null) {
      if (code == 401) return AppErrorKind.unauthorized;
      if (code == 404) return AppErrorKind.notFound;
      if (code == 409) return AppErrorKind.conflict;
      if (code >= 500) return AppErrorKind.server;
      if (code >= 400) return AppErrorKind.validation;
    }
    final c = cause;
    if (c is TimeoutException) return AppErrorKind.timeout;
    if (c is SocketException) return AppErrorKind.network;
    // Fall back to the message only when no structured signal is available
    // (e.g. an exception constructed before causes were threaded through).
    if (c == null) {
      if (message.contains('TimeoutException')) return AppErrorKind.timeout;
      if (message.contains('SocketException')) return AppErrorKind.network;
    }
    return AppErrorKind.unknown;
  }

  /// Builds an exception from a failed [http.Response], surfacing the server's
  /// own error message instead of a bare status code. The backend returns
  /// `{"error": "..."}` (see ApiError on the server) for 4xx/5xx; we extract
  /// that so the UI shows the real reason (e.g. "Validation error: Pickup
  /// location cannot be empty") rather than just "400". Falls back to the raw
  /// body, then to the status code, when the body isn't the expected shape.
  factory ApiException.fromResponse(http.Response response, String action) {
    String detail = 'status ${response.statusCode}';
    ScheduleConflictInfo? conflict;
    final body = response.body.trim();
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic> && decoded['error'] is String) {
          detail = decoded['error'] as String;
          final sc = decoded['scheduleConflict'];
          if (sc is Map<String, dynamic>) {
            conflict = ScheduleConflictInfo.fromJson(sc);
          }
        } else {
          detail = body;
        }
      } on FormatException {
        detail = body;
      }
    }
    return ApiException(
      '$action: $detail',
      statusCode: response.statusCode,
      scheduleConflict: conflict,
    );
  }

  @override
  String toString() => 'ApiException: $message';
}

/// Structured details of a schedule conflict, mirroring the server's
/// ScheduleConflictDetails. All fields optional — the manual-unavailability
/// conflict carries none of them.
class ScheduleConflictInfo {
  final String? rideId;
  final String? clientId;
  final String? from;
  final String? to;

  /// ISO-8601 UTC instant of the conflicting ride's pickup time (parse + format
  /// to the viewer's local time for display).
  final String? pickupAt;

  const ScheduleConflictInfo({
    this.rideId,
    this.clientId,
    this.from,
    this.to,
    this.pickupAt,
  });

  factory ScheduleConflictInfo.fromJson(Map<String, dynamic> json) =>
      ScheduleConflictInfo(
        rideId: json['rideId'] as String?,
        clientId: json['clientId'] as String?,
        from: json['from'] as String?,
        to: json['to'] as String?,
        pickupAt: json['pickupAt'] as String?,
      );
}
