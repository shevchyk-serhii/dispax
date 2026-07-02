import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// MULTI-DISPATCHER (assign race): two dispatchers of the SAME company race to
/// grab the same Requested ride.
///
/// Dispatcher A (Iryna) is on the Pending board in the UI. Dispatcher B (Yilmaz)
/// grabs the ride first via the HTTP API (the only honest way to win the race
/// while A's UI still holds the stale Pending row — Patrol runs a single app
/// instance). When A then tries to assign the same ride, the backend rejects it
/// with HTTP 409 "Ride already assigned". The dispatcher must NOT see a red
/// failure with a doomed Retry; instead an info SnackBar appears and the pending
/// list is silently reloaded so the now-assigned ride leaves the Pending tab.
///
/// Regression for the stale-assign handling (RideBloc._isAlreadyAssigned →
/// alreadyAssigned status, commits bddaf623 + 6090193c). Mutation check: revert
/// the `_isAlreadyAssigned` branch in ride_bloc.dart and this test must go red
/// (the 409 then surfaces as a generic error/Retry instead of the info text).
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

Future<int> _assign(
  String dispatcherToken,
  String rideId,
  String driverId,
) async {
  final r = await http.put(
    Uri.parse('$_base/rides/$rideId/assign-driver'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $dispatcherToken',
    },
    body: jsonEncode({'driverId': driverId}),
  );
  return r.statusCode;
}

void main() {
  patrolTest(
    'two dispatchers race to assign one ride: loser sees already-assigned info',
    ($) async {
      await resetTestData();

      // Seed one Requested ride (no driver yet) as the BMW client.
      final bmwToken = await _login(kDevClient1);
      final rideId = await _createRide(
        bmwToken,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      await bootstrapTestApp();
      await $.pumpAndSettle();

      // Dispatcher A opens the Pending board.
      await loginViaUi($, kDevDispatcherA, kDevPassword);
      if (skipIfBackendDown($)) return;

      await tapNav($, 'Home');
      await $(
        'Marienplatz, München',
      ).waitUntilVisible(timeout: const Duration(seconds: 20));

      // Dispatcher B (different account, same company) grabs the ride first via
      // the API — this is the "other dispatcher won the race" moment.
      final dispBToken = await _login(kDevDispatcherB);
      final bStatus = await _assign(dispBToken, rideId, _hansDriver);
      expect(
        bStatus,
        anyOf(200, 204),
        reason: 'Dispatcher B should win the assign',
      );

      // A's UI still shows the ride in Pending (stale). A taps Assign on it.
      await $('Assign').waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Assign').scrollTo().tap();
      // The dashboard animates forever; poll for the sheet instead of settling.
      await pumpUntilVisible($, find.text('Select Driver'));

      // Driver selection sheet → pick Klaus (a different driver than B chose).
      expect($('Select Driver'), findsWidgets);
      await $('Klaus Fischer').scrollTo().tap();
      await pumpUntilVisible($, find.text('Assign driver'));

      // Confirm in the AssignmentDialog ("Assign driver", no local conflict).
      if ($('Assign driver').exists) {
        await $('Assign driver').tap();
      }

      // The backend rejected A with 409 already-assigned. Two observable effects
      // prove the loser was handled gracefully (not a red error with a doomed
      // Retry): the info SnackBar, and — because the SnackBar auto-dismisses —
      // the durable one: the bloc silently reloaded the pending list, so the now
      // -assigned ride left the Pending tab. Catch the SnackBar if we can, but
      // accept the durable reload effect as the primary signal.
      final sawSnack = await pumpUntilVisible(
        $,
        find.textContaining('already assigned'),
        timeout: const Duration(seconds: 6),
      );
      // Let the silent reload settle regardless.
      await pumpFor($, const Duration(seconds: 2));

      final rideGoneFromPending =
          find.text('Marienplatz, München').evaluate().isEmpty;
      expect(
        sawSnack || rideGoneFromPending,
        isTrue,
        reason:
            'Loser must be handled gracefully: an already-assigned info '
            'SnackBar and/or the stale ride removed from Pending by reload',
      );

      // The crucial negative: no red "already assigned was treated as a doomed
      // retry/failure" leaked, and we are still logged in.
      expect(find.textContaining('Failed to assign'), findsNothing);
      expect($('Sign in'), findsNothing);
    },
  );
}
