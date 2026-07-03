import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// REGRESSION (self-conflict): reassigning a ride to the SAME driver it is
/// already on must NOT report the ride as conflicting with itself.
///
/// A single ride assigned to Hans. On the Assigned tab we Reassign it and pick
/// Hans again. The ConflictDetector skips `existing.id == newRide.id`, so Hans
/// shows no time conflict and the confirmation dialog offers the plain
/// "Assign driver" button — NOT the orange "Assign Anyway" that a self-conflict
/// would wrongly trigger (fixed in commit b95713b8).
///
/// Mutation check: remove the `existing.id == newRide.id` guard in
/// conflict_detector.dart and the dialog flips to "Assign Anyway" → this test
/// (which asserts "Assign driver" appears and "Assign Anyway" does not) goes red.
const String _base = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8090/api',
);

const String _bmwClient = '66666666-6666-6666-6666-666666666666';
const String _hansDriver = '33333333-3333-3333-3333-333333333333';

Future<String> _login(String email) async {
  final r = await http.post(
    Uri.parse('$_base/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': kDevPassword}),
  );
  return (jsonDecode(r.body) as Map<String, dynamic>)['token'] as String;
}

Future<String> _createRide(String clientToken, DateTime pickupUtc) async {
  final res = await http.post(
    Uri.parse('$_base/rides'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $clientToken',
    },
    body: jsonEncode({
      'clientId': _bmwClient,
      'creatorId': _bmwClient,
      'clientName': 'BMW AG - Herr Schneider',
      'pickupDateTime': pickupUtc.toIso8601String(),
      'from': {'address': 'Marienplatz, München'},
      'to': {'address': 'Flughafen München'},
    }),
  );
  return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String;
}

Future<void> _assign(
  String dispatcherToken,
  String rideId,
  String driverId,
) async {
  await http.put(
    Uri.parse('$_base/rides/$rideId/assign-driver'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $dispatcherToken',
    },
    body: jsonEncode({'driverId': driverId}),
  );
}

void main() {
  patrolTest('reassigning a ride to the same driver shows no self-conflict', (
    $,
  ) async {
    await resetTestData();

    final dispToken = await _login(kDevDispatcherA);
    final bmwToken = await _login(kDevClient1);

    final rideId = await _createRide(
      bmwToken,
      DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
    await _assign(dispToken, rideId, _hansDriver);

    await bootstrapTestApp();
    await pumpFor($, const Duration(seconds: 2));

    await loginViaUi($, kDevDispatcherA, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Home');
    await $('Assigned').waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Assigned').tap();
    await pumpFor($, const Duration(seconds: 2));

    await $('Reassign').waitUntilVisible(timeout: const Duration(seconds: 15));
    await $('Reassign').scrollTo().tap();
    await pumpFor($, const Duration(seconds: 3));

    expect($('Reassign Driver'), findsWidgets);

    // The driver sheet must not flag Hans (the current driver) as conflicting
    // with the very ride being reassigned.
    expect(
      find.textContaining('time conflict'),
      findsNothing,
      reason: 'A ride must not conflict with itself in the driver sheet',
    );

    await $('Hans Weber').scrollTo().tap();
    await pumpFor($, const Duration(seconds: 2));

    // No self-conflict → the confirm dialog shows the plain "Assign driver"
    // button, never the orange "Assign Anyway".
    expect(
      find.text('Assign Anyway'),
      findsNothing,
      reason: 'Self-reassign must not be treated as a schedule conflict',
    );
    expect($('Assign driver'), findsWidgets);

    await $('Assign driver').tap();
    await pumpFor($, const Duration(seconds: 3));

    expect(find.textContaining('Failed to reassign'), findsNothing);
    expect($('Sign in'), findsNothing);
  });
}
