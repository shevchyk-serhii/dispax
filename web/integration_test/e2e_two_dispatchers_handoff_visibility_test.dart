import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// MULTI-DISPATCHER (hand-off visibility): dispatcher B hands a ride off to an
/// external partner; dispatcher A (same company) must SEE the result — the ride
/// shows up on the Assigned tab as "Handed Off", read-only (no Reassign button),
/// instead of silently vanishing.
///
/// B performs the hand-off via the HTTP API (seed a partner company + external
/// driver, then PUT /rides/{id}/hand-off). A then opens the dashboard and the
/// handed-off ride must be visible with the HandedOff badge. This locks the
/// "hand-off result silently lost" + "HandedOff stays visible read-only" fixes
/// (commits 5ebad636, b6095393, and the Assigned-tab HandedOff rendering).
///
/// Mutation check: drop `RideStatus.handedOff` from the Assigned-tab filter in
/// pending_rides_panel.dart (or render Reassign for it) and this test goes red.
const String _base = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8090/api',
);

const String _bmwClient = '66666666-6666-6666-6666-666666666666';

Future<String> _login(String email) async {
  final r = await http.post(
    Uri.parse('$_base/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': kDevPassword}),
  );
  return (jsonDecode(r.body) as Map<String, dynamic>)['token'] as String;
}

Future<Map<String, dynamic>> _post(
  String token,
  String path,
  Map<String, dynamic> body,
) async {
  final r = await http.post(
    Uri.parse('$_base$path'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
  return jsonDecode(r.body) as Map<String, dynamic>;
}

Future<String> _createRide(String clientToken, DateTime pickupUtc) async {
  final res = await _post(clientToken, '/rides', {
    'clientId': _bmwClient,
    'creatorId': _bmwClient,
    'clientName': 'BMW AG - Herr Schneider',
    'pickupDateTime': pickupUtc.toIso8601String(),
    'from': {'address': 'Marienplatz, München'},
    'to': {'address': 'Flughafen München'},
  });
  return res['id'] as String;
}

/// Seeds a partner company + external driver as dispatcher B and hands the ride
/// off to them. Returns the resulting hand-off HTTP status.
Future<int> _handOffViaApi(String dispToken, String rideId) async {
  final partner = await _post(dispToken, '/partner-companies', {
    'name': 'Partner Taxi GmbH',
    'phone': '+49 89 9999999',
  });
  final extDriver = await _post(dispToken, '/external-drivers', {
    'name': 'External Otto',
    'phone': '+49 170 9999999',
    'partnerCompanyId': partner['id'],
  });
  final r = await http.put(
    Uri.parse('$_base/rides/$rideId/hand-off'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $dispToken',
    },
    body: jsonEncode({
      'externalDriverId': extDriver['id'],
      'partnerCompanyId': partner['id'],
    }),
  );
  return r.statusCode;
}

void main() {
  patrolTest(
    'dispatcher A sees a ride handed off by dispatcher B as read-only HandedOff',
    ($) async {
      await resetTestData();

      // Seed a Requested ride.
      final bmwToken = await _login(kDevClient1);
      final rideId = await _createRide(
        bmwToken,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      // Dispatcher B hands it off via the API.
      final dispBToken = await _login(kDevDispatcherB);
      final hoStatus = await _handOffViaApi(dispBToken, rideId);
      expect(hoStatus, 200, reason: 'Hand-off should succeed for dispatcher B');

      await bootstrapTestApp();
      await $.pumpAndSettle();

      // Dispatcher A opens the board and switches to the Assigned tab.
      await loginViaUi($, kDevDispatcherA, kDevPassword);
      if (skipIfBackendDown($)) return;

      await tapNav($, 'Home');
      await $(
        'Assigned',
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $('Assigned').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      // The handed-off ride is visible with the "Handed Off" badge.
      await $(
        'Handed Off',
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      expect(find.text('Handed Off'), findsWidgets);

      // It is read-only: a handed-off ride renders no Reassign button (the
      // Reassign action only exists for assigned/confirmed rides). This is the
      // only ride on the board, so there must be no Reassign affordance at all.
      expect(
        find.text('Reassign'),
        findsNothing,
        reason: 'A handed-off ride must be read-only (no Reassign)',
      );

      expect($('Sign in'), findsNothing);
    },
  );
}
