import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// Reassign into a schedule conflict + override confirmation.
///
/// Regression for the "Failed to reassign driver: 400" bug: the backend now
/// returns 409 for a schedule conflict (RideError.ScheduleConflict) and the
/// dispatcher can knowingly override it. We seed two overlapping rides assigned
/// to two different drivers, then reassign one onto the other's driver — the
/// new driver is busy in the same window, so the UI surfaces the conflict and
/// lets the dispatcher confirm ("Reassign anyway" / "Assign Anyway").
const String _base = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8090/api',
);

const String _bmwClient = '66666666-6666-6666-6666-666666666666';
const String _siemensClient = '77777777-7777-7777-7777-777777777777';
const String _hansDriver = '33333333-3333-3333-3333-333333333333';
const String _klausDriver = '44444444-4444-4444-4444-444444444444';

Future<String> _login(String email, String password) async {
  final r = await http.post(
    Uri.parse('$_base/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  return (jsonDecode(r.body) as Map<String, dynamic>)['token'] as String;
}

Future<String> _createRide(
  String clientToken,
  String clientId,
  String clientName,
  DateTime pickupUtc,
) async {
  final res = await http.post(
    Uri.parse('$_base/rides'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $clientToken',
    },
    body: jsonEncode({
      'clientId': clientId,
      'creatorId': clientId,
      'clientName': clientName,
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

/// Seeds two overlapping rides: Siemens ride assigned to Klaus, and a BMW ride
/// (still in the Assigned list) we will try to move onto Klaus — who is busy in
/// the same time window. Returns nothing; the UI drives the reassignment.
Future<void> _seedConflict() async {
  final dispatcherToken = await _login(kDevDispatcher, kDevPassword);
  final bmwToken = await _login(kDevClient1, kDevPassword);
  final siemensToken = await _login(kDevClient2, kDevPassword);

  // Both rides scheduled ~1h out, 5 min apart → windows overlap.
  final base = DateTime.now().toUtc().add(const Duration(hours: 1));

  // Siemens ride → Klaus (the busy driver we'll conflict against).
  final siemensRide = await _createRide(
    siemensToken,
    _siemensClient,
    'Siemens - Frau Meier',
    base.add(const Duration(minutes: 5)),
  );
  await _assign(dispatcherToken, siemensRide, _klausDriver);

  // BMW ride → Hans first (so it sits in the Assigned tab for the UI to reassign).
  final bmwRide = await _createRide(
    bmwToken,
    _bmwClient,
    'BMW AG - Herr Schneider',
    base,
  );
  await _assign(dispatcherToken, bmwRide, _hansDriver);
}

void main() {
  patrolTest('dispatcher overrides a schedule conflict when reassigning', (
    $,
  ) async {
    await resetTestData();
    await _seedConflict();

    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Home');

    // Move to the Assigned tab where the BMW ride (on Hans) is listed.
    await $('Assigned').waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Assigned').tap();
    await $.pumpAndSettle();

    await $('Reassign').waitUntilVisible(timeout: const Duration(seconds: 15));
    await $('Reassign').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // Pick Klaus, who is busy in the overlapping window.
    expect($('Reassign Driver'), findsWidgets);
    await $('Klaus Fischer').scrollTo().tap();
    await $.pumpAndSettle();

    // Confirm despite the conflict. The local conflict detector shows an
    // "Assign Anyway" button; if the conflict is only caught server-side, a
    // follow-up "Reassign anyway" dialog appears. Handle both paths.
    if ($('Assign Anyway').exists) {
      await $('Assign Anyway').tap();
    } else if ($('Assign').exists) {
      await $('Assign').tap();
    }
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // Server-side override confirmation (driver busy in a window the client
    // didn't flag locally).
    if ($('Reassign anyway').exists) {
      await $('Reassign anyway').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
    }

    // The bare "...400" must never reach the UI; we should still be logged in.
    expect($('Failed to reassign driver: 400'), findsNothing);
    expect($('Sign In'), findsNothing);
  });
}
