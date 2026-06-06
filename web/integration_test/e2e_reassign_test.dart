import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// Driver reassignment: the dispatcher assigns a fresh ride to Hans (driver1),
/// then reassigns it to Klaus (driver2) via the Assigned tab → Reassign →
/// "Reassign Driver" sheet → AssignmentDialog.
///
/// The assignment must happen in-session through the UI: the dispatcher panel
/// loads only pending rides (`GET /rides/pending`), so a pre-assigned ride
/// wouldn't show up in the Assigned tab on load.
const String _base = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8090/api',
);

const String _bmwClient = '66666666-6666-6666-6666-666666666666';

Future<String> _login(String email, String password) async {
  final r = await http.post(
    Uri.parse('$_base/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  return (jsonDecode(r.body) as Map<String, dynamic>)['token'] as String;
}

/// Seeds a Requested ride for the dispatcher to assign in the UI.
Future<void> _seedRequestedRide() async {
  final clientToken = await _login(kDevClient1, kDevPassword);
  final pickup = DateTime.now()
      .toUtc()
      .add(const Duration(hours: 1))
      .toIso8601String();
  await http.post(
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
}

void main() {
  patrolTest('dispatcher assigns then reassigns a ride', ($) async {
    await _seedRequestedRide();

    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Home');
    if ($('Pending').exists) {
      await $('Pending').tap();
      await $.pumpAndSettle();
    }

    // Assign Hans first (so the ride enters the in-session Assigned list).
    // The pending card shows the from-address on its own line.
    await $(
      'Marienplatz, München',
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Marienplatz, München').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $('Hans Weber').scrollTo().tap();
    await $.pumpAndSettle();
    await ($('Assign Anyway').exists ? $('Assign Anyway') : $('Assign')).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    // Switch to the Assigned tab and reassign to Klaus.
    await $('Assigned').tap();
    await $.pumpAndSettle();
    await $('Reassign').waitUntilVisible(timeout: const Duration(seconds: 15));
    await $('Reassign').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    expect($('Reassign Driver'), findsWidgets);
    await $('Klaus Fischer').scrollTo().tap();
    await $.pumpAndSettle();
    await ($('Assign Anyway').exists ? $('Assign Anyway') : $('Assign')).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    expect($('Sign In'), findsNothing);
  });
}
