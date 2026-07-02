import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// REGRESSION (assign-side conflict override): assigning a Requested ride to a
/// driver who is already busy in the overlapping window surfaces the local
/// "Assign Anyway" confirmation, and confirming it goes through (the backend
/// override succeeds, no raw 409/400 reaches the UI).
///
/// Complements e2e_reassign_conflict_test (which covers the reassign side). We
/// seed an Assigned ride on Hans plus an overlapping Requested ride, then in the
/// UI assign the Requested ride to the busy Hans. The local ConflictDetector
/// (±60 min) flags the overlap → AssignmentDialog shows "Assign Anyway" →
/// confirming dispatches overrideScheduleConflict=true.
///
/// Mutation check: force conflicts to be ignored on assign (e.g. always pass
/// overrideScheduleConflict=false, or empty the conflicts list) and either the
/// "Assign Anyway" button never appears (test red) or a raw failure leaks.
const String _base = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8090/api',
);

const String _bmwClient = '66666666-6666-6666-6666-666666666666';
const String _siemensClient = '77777777-7777-7777-7777-777777777777';
const String _hansDriver = '33333333-3333-3333-3333-333333333333';

Future<String> _login(String email) async {
  final r = await http.post(
    Uri.parse('$_base/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': kDevPassword}),
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

void main() {
  patrolTest(
    'assigning to a busy driver shows Assign Anyway and override succeeds',
    ($) async {
      await resetTestData();

      final dispToken = await _login(kDevDispatcherA);
      final siemensToken = await _login(kDevClient2);
      final bmwToken = await _login(kDevClient1);

      final base = DateTime.now().toUtc().add(const Duration(hours: 1));

      // Existing Assigned ride on Hans (will appear in the Assigned tab and in
      // RideBloc.state.rides, so the local detector can see it).
      final busyRide = await _createRide(
        siemensToken,
        _siemensClient,
        'Siemens - Frau Meier',
        base,
      );
      await _assign(dispToken, busyRide, _hansDriver);

      // Overlapping Requested ride (5 min later → within the ±60 min window).
      await _createRide(
        bmwToken,
        _bmwClient,
        'BMW AG - Herr Schneider',
        base.add(const Duration(minutes: 5)),
      );

      await bootstrapTestApp();
      await $.pumpAndSettle();

      await loginViaUi($, kDevDispatcherA, kDevPassword);
      if (skipIfBackendDown($)) return;

      await tapNav($, 'Home');

      // On the Pending tab, open the BMW (Requested) ride's driver sheet.
      await $(
        'BMW AG - Herr Schneider',
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $('Assign').waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Assign').scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      expect($('Select Driver'), findsWidgets);
      // Pick Hans, who is busy in the overlapping window.
      await $('Hans Weber').scrollTo().tap();
      await $.pumpAndSettle();

      // The AssignmentDialog must offer "Assign Anyway" (local conflict found).
      await $(
        'Assign Anyway',
      ).waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Assign Anyway').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));

      // The override went through: no raw failure, still logged in.
      expect(find.textContaining('Failed to assign'), findsNothing);
      expect(find.textContaining('409'), findsNothing);
      expect($('Sign in'), findsNothing);
    },
  );
}
