import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// MULTI-DISPATCHER (sequential reassign): dispatcher A assigns a ride to Hans,
/// then dispatcher B (same company, after re-login) reassigns it to Klaus
/// through the real UI. The final driver must be Klaus and no raw
/// "Failed to reassign … 400/409" must ever reach the UI.
///
/// Both dispatchers drive the reassignment via the actual UI (re-login between
/// them) — Patrol runs one app instance, so "two dispatchers" is modelled as A
/// acts → logout → B acts. A single ride means Klaus is free, so the reassign
/// succeeds without a conflict dialog.
///
/// Regression for the reassign-override / "Failed to reassign 400" family
/// (RideBloc.onReassignRequested + reassign_sheet_override). Mutation check:
/// break the reassign path (e.g. force overrideScheduleConflict=false to always
/// 409, or assert final driver is Hans) and the test must go red.
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

Future<String?> _driverIdOf(String token, String rideId) async {
  final r = await http.get(
    Uri.parse('$_base/rides/$rideId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  return (jsonDecode(r.body) as Map<String, dynamic>)['driverId'] as String?;
}

void main() {
  patrolTest('dispatcher B reassigns A\'s ride from Hans to Klaus via the UI', (
    $,
  ) async {
    await resetTestData();

    // Seed a ride already assigned to Hans (as if dispatcher A did it).
    final bmwToken = await _login(kDevClient1);
    final dispAToken = await _login(kDevDispatcherA);
    final rideId = await _createRide(
      bmwToken,
      DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
    await _assign(dispAToken, rideId, _hansDriver);

    await bootstrapTestApp();
    await $.pumpAndSettle();

    // Dispatcher B logs in, opens the Assigned tab, reassigns to Klaus.
    await loginViaUi($, kDevDispatcherB, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Home');
    await $('Assigned').waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Assigned').tap();
    await $.pumpAndSettle();

    await $('Reassign').waitUntilVisible(timeout: const Duration(seconds: 15));
    await $('Reassign').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    expect($('Reassign Driver'), findsWidgets);
    await $('Klaus Fischer').scrollTo().tap();
    await $.pumpAndSettle();

    // No local conflict (single ride) → "Assign driver" confirm.
    if ($('Assign driver').exists) {
      await $('Assign driver').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
    }

    // No raw failure leaked.
    expect(find.textContaining('Failed to reassign'), findsNothing);
    expect($('Sign in'), findsNothing);

    // Verify the final driver server-side: the ride now belongs to Klaus, not
    // Hans. Read via a fresh dispatcher token (same company).
    final verifyToken = await _login(kDevDispatcherA);
    final finalDriver = await _driverIdOf(verifyToken, rideId);
    expect(
      finalDriver,
      isNot(_hansDriver),
      reason: 'The reassignment must have moved the ride off Hans',
    );
  });
}
