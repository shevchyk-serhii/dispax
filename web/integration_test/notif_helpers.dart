import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// Shared helpers for the notification e2e suites (e2e_notif_*).
///
/// All tests run against the full backend (Flyway dev-data) on TEST_PORT,
/// reached via `--dart-define=API_BASE_URL=...`. They seed rides over the API
/// (same pattern as e2e_chat_test.dart), then assert on the in-app inbox both
/// via REST (`/api/notifications`) and via the "Notifications" UI screen.

/// Seed-account UUIDs (from V2__Insert_seed_accounts.sql, single company).
const String bmwClientId = '66666666-6666-6666-6666-666666666666';
const String siemensClientId = '77777777-7777-7777-7777-777777777777';
const String hansDriverId = '33333333-3333-3333-3333-333333333333';

/// Logs in via the REST API and returns the JWT token.
Future<String> apiLogin(String email, String password) async {
  final r = await http.post(
    Uri.parse('$kApiBaseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  return (jsonDecode(r.body) as Map<String, dynamic>)['token'] as String;
}

/// Creates a ride as the BMW client (returns the ride id).
Future<String> seedRequestedRide({String? token}) async {
  final clientToken = token ?? await apiLogin(kDevClient1, kDevPassword);
  final pickup =
      DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();
  final res = await http.post(
    Uri.parse('$kApiBaseUrl/rides'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $clientToken',
    },
    body: jsonEncode({
      'clientId': bmwClientId,
      'creatorId': bmwClientId,
      'clientName': 'BMW AG - Herr Schneider',
      'pickupDateTime': pickup,
      'from': {'address': 'Marienplatz, München'},
      'to': {'address': 'Flughafen München'},
    }),
  );
  return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String;
}

/// Assigns Hans (driver1) to the given ride as the dispatcher.
Future<void> assignDriver(String rideId, {String driverId = hansDriverId}) async {
  final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
  await http.put(
    Uri.parse('$kApiBaseUrl/rides/$rideId/assign-driver'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $dispatcherToken',
    },
    body: jsonEncode({'driverId': driverId}),
  );
}

/// Creates a ride and assigns Hans, leaving it in the Assigned state. Returns id.
Future<String> seedAssignedRide() async {
  final rideId = await seedRequestedRide();
  await assignDriver(rideId);
  return rideId;
}

/// Transitions a ride's status (Requested/Assigned/InProgress/Completed/Cancelled)
/// as the dispatcher (allowed for any of the company's rides).
Future<void> setStatus(String rideId, String status) async {
  final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
  await http.put(
    Uri.parse('$kApiBaseUrl/rides/$rideId/status'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $dispatcherToken',
    },
    body: jsonEncode({'status': status}),
  );
}

/// Cancels a ride with a reason as the dispatcher.
Future<void> cancelRide(String rideId, {String reason = 'Client no-show'}) async {
  final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
  await http.put(
    Uri.parse('$kApiBaseUrl/rides/$rideId/cancel'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $dispatcherToken',
    },
    body: jsonEncode({'reason': reason}),
  );
}

/// REST: returns the unread notification count for the token's user.
Future<int> unreadCount(String token) async {
  final r = await http.get(
    Uri.parse('$kApiBaseUrl/notifications/unread-count'),
    headers: {'Authorization': 'Bearer $token'},
  );
  return (jsonDecode(r.body) as Map<String, dynamic>)['count'] as int;
}

/// REST: returns the raw notification list for the token's user. Uses a high
/// limit so assertions don't silently hit the default page size (20) when an
/// inbox has accumulated entries across runs.
Future<List<Map<String, dynamic>>> fetchNotifications(String token,
    {int limit = 100}) async {
  final r = await http.get(
    Uri.parse('$kApiBaseUrl/notifications?limit=$limit'),
    headers: {'Authorization': 'Bearer $token'},
  );
  final decoded = jsonDecode(r.body);
  if (decoded is! List) return const [];
  return decoded.cast<Map<String, dynamic>>();
}

/// REST: deletes all notifications for the token's user. Use to start a test
/// from a clean inbox (POST /api/dev/reset clears rides but not notifications).
Future<void> clearNotifications(String token) async {
  await http.delete(
    Uri.parse('$kApiBaseUrl/notifications'),
    headers: {'Authorization': 'Bearer $token'},
  );
}

/// Polls the inbox until a notification matching [test] appears, or the timeout
/// elapses. Some notifications are produced asynchronously (e.g. proximity
/// events flow through the geofence service then the EventHub listener), so a
/// single read can race the write. Returns the matching list (possibly empty on
/// timeout, so callers still assert on it).
Future<List<Map<String, dynamic>>> waitForNotification(
  String token,
  bool Function(Map<String, dynamic>) test, {
  Duration timeout = const Duration(seconds: 8),
  Duration interval = const Duration(milliseconds: 400),
}) async {
  final deadline = DateTime.now().add(timeout);
  var notifs = await fetchNotifications(token);
  while (!notifs.any(test) && DateTime.now().isBefore(deadline)) {
    await Future.delayed(interval);
    notifs = await fetchNotifications(token);
  }
  return notifs;
}

/// Opens the in-app Notifications screen by tapping the NotificationBell in the
/// app bar. The bell is mounted on the driver/dispatcher/secretary dashboards.
/// Lands on a screen whose app bar title is "Notifications".
Future<void> openNotifications(PatrolIntegrationTester $) async {
  final bell = find.byIcon(Icons.notifications_outlined);
  expect(bell, findsWidgets,
      reason: 'NotificationBell (notifications_outlined) should be in the app bar');
  await $.tester.tap(bell.first, warnIfMissed: false);
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await $('Notifications')
      .waitUntilVisible(timeout: const Duration(seconds: 15));
}
