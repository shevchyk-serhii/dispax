import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// NEGATIVE (tenant isolation): a dispatcher only ever sees and touches their
/// OWN company's data.
///
/// Three layers of isolation are checked for the München dispatcher (Iryna):
///  1. Board: Company 2 (Taxi Schwabing) rides — "Schwabing Markt" / Audi — must
///     not appear on the Pending/Assigned tabs.
///  2. Driver sheet: Company 2's driver (Maria Hoffmann) must not be selectable
///     when assigning a Company 1 ride.
///  3. API: assigning a Company 1 ride to a Company 2 driver must be rejected
///     (the backend scopes assignment by the JWT companyId — 404/403, not 200).
const String _base = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8090/api',
);

const String _bmwClient = '66666666-6666-6666-6666-666666666666';
const String _schwabingDriver = 'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2';

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
    'dispatcher cannot see or assign another company\'s rides and drivers',
    ($) async {
      await resetTestData();

      // Seed one Company 1 Requested ride so the driver sheet can be opened.
      final bmwToken = await _login(kDevClient1);
      final rideId = await _createRide(
        bmwToken,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      // 3. API isolation: the München dispatcher cannot assign the ride to the
      //    Schwabing driver. The backend must reject (not 200).
      final dispToken = await _login(kDevDispatcherA);
      final crossStatus = await _assign(dispToken, rideId, _schwabingDriver);
      expect(
        crossStatus,
        isNot(anyOf(200, 204)),
        reason: 'Assigning across tenants must be rejected by the backend',
      );

      await bootstrapTestApp();
      await $.pumpAndSettle();

      await loginViaUi($, kDevDispatcherA, kDevPassword);
      if (skipIfBackendDown($)) return;

      await tapNav($, 'Home');
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));

      // 1. Board isolation: no Company 2 rides/clients on either tab.
      for (final tab in const ['Pending', 'Assigned']) {
        if ($(tab).exists) {
          await $(tab).tap();
          await $.pumpAndSettle(timeout: const Duration(seconds: 10));
        }
        expect(
          find.textContaining('Schwabing Markt'),
          findsNothing,
          reason: 'Company 2 ride must not appear on the $tab tab',
        );
        expect(
          find.textContaining('Audi'),
          findsNothing,
          reason: 'Company 2 client must not appear on the $tab tab',
        );
      }

      // 2. Driver-sheet isolation: open the Company 1 ride's driver picker and
      //    confirm the Schwabing driver is not listed.
      await $('Pending').tap();
      await $.pumpAndSettle();
      await $(
        'Marienplatz, München',
      ).waitUntilVisible(timeout: const Duration(seconds: 15));
      await $('Assign').waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Assign').scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      expect($('Select Driver'), findsWidgets);
      expect(
        find.textContaining('Maria Hoffmann'),
        findsNothing,
        reason: 'Another company\'s driver must not be selectable',
      );

      expect($('Sign in'), findsNothing);
    },
  );
}
