import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// Chat happy-path: a ride must be active (assigned/inProgress) for chat to be
/// available, so we seed an assigned ride via the API, then drive the UI:
/// client opens the ride → Open Chat → types a message → sends it.
/// Exercises POST /rides/{id}/chat.
const String _base = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8090/api',
);

const String _bmwClient = '66666666-6666-6666-6666-666666666666';
const String _hansDriver = '33333333-3333-3333-3333-333333333333';

Future<String> _login(String email, String password) async {
  final r = await http.post(
    Uri.parse('$_base/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  return (jsonDecode(r.body) as Map<String, dynamic>)['token'] as String;
}

/// Creates a ride as the client and assigns Hans (driver1) as dispatcher,
/// leaving it in the assigned state so chat is available. Returns the ride id.
Future<String> _seedAssignedRide() async {
  final clientToken = await _login(kDevClient1, kDevPassword);
  final pickup = DateTime.now()
      .toUtc()
      .add(const Duration(hours: 1))
      .toIso8601String();
  final createRes = await http.post(
    Uri.parse('$_base/rides'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $clientToken',
    },
    body: jsonEncode({
      'clientId': _bmwClient,
      'creatorId': _bmwClient,
      'clientName': 'BMW AG - Herr Schneider',
      'pickupDateTime': pickup,
      'from': {'address': 'Marienplatz, München'},
      'to': {'address': 'Flughafen München'},
    }),
  );
  final rideId =
      (jsonDecode(createRes.body) as Map<String, dynamic>)['id'] as String;

  final dispatcherToken = await _login(kDevDispatcher, kDevPassword);
  await http.put(
    Uri.parse('$_base/rides/$rideId/assign-driver'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $dispatcherToken',
    },
    body: jsonEncode({'driverId': _hansDriver}),
  );
  return rideId;
}

void main() {
  patrolTest('client sends a chat message on an active ride', ($) async {
    await _seedAssignedRide();

    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Home shows the active ride; open its details.
    await tapNav($, 'Home');
    await $(
      'Marienplatz, München → Flughafen München',
    ).waitUntilVisible(timeout: const Duration(seconds: 15));
    await $('Marienplatz, München → Flughafen München').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // Open the chat for this active ride.
    await $('Open Chat').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // Type a message and send it.
    final input = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Type a message...',
    );
    await $.tester.enterText(input, 'Hello from E2E');
    await $.pumpAndSettle();
    await $(Icons.send).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // The sent message appears in the conversation.
    expect($('Hello from E2E'), findsWidgets);
  });
}
