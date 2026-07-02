import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';

/// WEBSOCKET (live status): a ride confirmed by the driver updates the
/// dispatcher's board live, without a manual refresh.
///
/// Dispatcher A watches the Assigned tab with a ride assigned to Hans (badge
/// "Assigned"). The driver (Hans) confirms the ride via the API, which makes the
/// backend broadcast a RideStatusChanged WebSocket event. The app's global WS
/// listener (main.dart) turns it into RideStatusReceived → RideBloc updates the
/// ride in place → the badge flips to "Confirmed" on A's screen with no refresh.
///
/// This is the GREEN dispatcher WS flow (contrast with the red RideCreated-live
/// suite). Mutation check: drop the RideStatusChanged→RideStatusReceived wiring
/// in main.dart (or the onStatusReceived handler in ride_bloc.dart) and the
/// badge never updates → this test goes red.
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

Future<void> _confirm(String driverToken, String rideId) async {
  await http.put(
    Uri.parse('$_base/rides/$rideId/confirm'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $driverToken',
    },
  );
}

/// Pumps in bounded steps until [text] is visible or the timeout elapses.
/// The dispatcher dashboard runs perpetual animations, so pumpAndSettle never
/// returns — we poll for the live WS-driven badge change instead.
Future<bool> _pumpUntilText(
  PatrolIntegrationTester $,
  String text, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  const step = Duration(milliseconds: 300);
  var elapsed = Duration.zero;
  while (elapsed < timeout) {
    await $.pump(step);
    elapsed += step;
    if (find.text(text).evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  patrolTest(
    'driver confirm updates the dispatcher board live over WebSocket',
    ($) async {
      await resetTestData();

      final dispToken = await _login(kDevDispatcherA);
      final bmwToken = await _login(kDevClient1);
      final rideId = await _createRide(
        bmwToken,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      await _assign(dispToken, rideId, _hansDriver);

      await bootstrapTestApp();
      await $.pumpAndSettle();

      await loginViaUi($, kDevDispatcherA, kDevPassword);
      if (skipIfBackendDown($)) return;

      await tapNav($, 'Home');
      await $(
        'Assigned',
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $('Assigned').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      // Baseline: the ride is on the Assigned tab as "Assigned".
      expect(
        await _pumpUntilText($, 'Assigned'),
        isTrue,
        reason: 'Ride should start as Assigned on the board',
      );

      // The driver confirms → backend broadcasts RideStatusChanged.
      final driverToken = await _login(kDevDriver1);
      await _confirm(driverToken, rideId);

      // The badge must flip to "Confirmed" live, without any manual refresh.
      final wentConfirmed = await _pumpUntilText($, 'Confirmed');
      expect(
        wentConfirmed,
        isTrue,
        reason: 'Dispatcher board must reflect the confirm live over WebSocket',
      );

      expect($('Sign in'), findsNothing);
    },
  );
}
