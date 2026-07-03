import 'dart:convert';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// Helpers for the negative / edge-case ride-flow suites (e2e_ride_*).
///
/// They run against the full backend (Flyway dev-data) on TEST_PORT and assert
/// both the HTTP rejection AND that the ride's state did not change — the class
/// of bug current happy-path tests miss (optimistic UI showing false success).
///
/// Seed-account UUIDs from V2__Insert_seed_accounts.sql (single company):
const String bmwClientId = '66666666-6666-6666-6666-666666666666';
const String siemensClientId = '77777777-7777-7777-7777-777777777777';
const String hansDriverId = '33333333-3333-3333-3333-333333333333';
const String klausDriverId = '44444444-4444-4444-4444-444444444444';
const String dispatcherId = '11111111-1111-1111-1111-111111111111';

/// A typed result of an HTTP call: the status code plus the decoded body.
class ApiResult {
  final int status;
  final dynamic body;
  ApiResult(this.status, this.body);

  /// The `error` field of an error envelope, if present.
  String? get error =>
      (body is Map && body['error'] is String) ? body['error'] as String : null;
}

Future<String> apiLogin(String email, String password) async {
  final r = await http.post(
    Uri.parse('$kApiBaseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  return (jsonDecode(r.body) as Map<String, dynamic>)['token'] as String;
}

dynamic _decode(http.Response r) {
  if (r.body.isEmpty) return null;
  try {
    return jsonDecode(r.body);
  } catch (_) {
    return r.body;
  }
}

Future<ApiResult> apiGet(String path, String token) async {
  final r = await http.get(
    Uri.parse('$kApiBaseUrl$path'),
    headers: {'Authorization': 'Bearer $token'},
  );
  return ApiResult(r.statusCode, _decode(r));
}

Future<ApiResult> apiPost(
  String path,
  String token,
  Map<String, dynamic> body,
) async {
  final r = await http.post(
    Uri.parse('$kApiBaseUrl$path'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
  return ApiResult(r.statusCode, _decode(r));
}

Future<ApiResult> apiPut(
  String path,
  String token,
  Map<String, dynamic> body,
) async {
  final r = await http.put(
    Uri.parse('$kApiBaseUrl$path'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
  return ApiResult(r.statusCode, _decode(r));
}

/// ISO-8601 UTC string for `now + offset`.
String pickupAt(Duration offset) =>
    DateTime.now().toUtc().add(offset).toIso8601String();

/// Creates a ride as the BMW client and returns its ApiResult (so callers can
/// assert success or a validation rejection). Override [from]/[to] to drive
/// validation cases (e.g. identical addresses).
Future<ApiResult> createRide(
  String clientToken, {
  String from = 'Marienplatz, München',
  String to = 'Flughafen München',
  String? pickupDateTime,
}) {
  return apiPost('/rides', clientToken, {
    'clientId': bmwClientId,
    'creatorId': bmwClientId,
    'clientName': 'BMW AG - Herr Schneider',
    'pickupDateTime': pickupDateTime ?? pickupAt(const Duration(hours: 1)),
    'from': {'address': from},
    'to': {'address': to},
  });
}

/// Convenience: create a ride and return its id (fails the test caller's
/// expectations naturally if creation did not return 200).
Future<String> createRideId(
  String clientToken, {
  String? pickupDateTime,
}) async {
  final res = await createRide(clientToken, pickupDateTime: pickupDateTime);
  return (res.body as Map<String, dynamic>)['id'] as String;
}

Future<ApiResult> assignDriver(
  String rideId,
  String dispatcherToken, {
  String driverId = hansDriverId,
}) => apiPut('/rides/$rideId/assign-driver', dispatcherToken, {
  'driverId': driverId,
});

Future<ApiResult> setStatus(String rideId, String token, String status) =>
    apiPut('/rides/$rideId/status', token, {'status': status});

Future<ApiResult> cancelRide(
  String rideId,
  String token, {
  String reason = 'Test cancel',
}) => apiPut('/rides/$rideId/cancel', token, {'reason': reason});

Future<ApiResult> addBlacklist(
  String dispatcherToken,
  String clientId,
  String driverId,
  String reason,
) => apiPost('/blacklist', dispatcherToken, {
  'clientId': clientId,
  'driverId': driverId,
  'reason': reason,
});

/// Reads a single ride's current status via GET /rides/{id}.
Future<String> rideStatus(String rideId, String token) async {
  final res = await apiGet('/rides/$rideId', token);
  return (res.body as Map<String, dynamic>)['status'] as String;
}

/// Reads a single ride's payment fields via GET /rides/{id}.
Future<Map<String, dynamic>> rideJson(String rideId, String token) async {
  final res = await apiGet('/rides/$rideId', token);
  return res.body as Map<String, dynamic>;
}

Future<ApiResult> markPaid(String rideId, String dispatcherToken) => apiPut(
  '/rides/$rideId/payment',
  dispatcherToken,
  {'paymentStatus': 'Paid'},
);

Future<ApiResult> createExpense(
  String driverToken, {
  required double amount,
  String category = 'Fuel',
}) =>
    apiPost('/expenses', driverToken, {'category': category, 'amount': amount});

Future<ApiResult> rateRide(String rideId, String clientToken, int rating) =>
    apiPost('/rides/$rideId/rate', clientToken, {'rating': rating});

/// Drives a ride from Requested through to Completed (client books, dispatcher
/// assigns + starts + completes). Returns the ride id.
Future<String> completeRide(String clientToken, String dispatcherToken) async {
  final rideId = await createRideId(clientToken);
  await assignDriver(rideId, dispatcherToken, driverId: hansDriverId);
  await setStatus(rideId, dispatcherToken, 'InProgress');
  await setStatus(rideId, dispatcherToken, 'Completed');
  return rideId;
}
