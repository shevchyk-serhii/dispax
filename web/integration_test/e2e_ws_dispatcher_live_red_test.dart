import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;

import 'patrol_helpers.dart';
import 'notif_helpers.dart';

/// RED: expected backend/frontend gap — see plan.
///
/// A dispatcher viewing the Pending list should see a newly booked ride appear
/// LIVE (the backend broadcasts RideCreated over WebSocket). Today the
/// dispatcher's PendingRidesPanel loads rides via REST (RideLoadPendingRequested)
/// and does not subscribe to the WebSocket stream, so a ride created while the
/// dispatcher is looking at the list does NOT show up until a manual refresh.
///
/// This test logs in as the dispatcher, creates a ride from another session via
/// the API, and waits for it to appear WITHOUT pulling to refresh. Expected to
/// FAIL until live updates are wired into the dispatcher list.
///
/// A unique drop-off address makes the new card unambiguous to match.
const String _uniqueDropoff = 'Olympiapark Live-Test, München';

Future<void> _createRideWithDropoff(String dropoff) async {
  final clientToken = await apiLogin(kDevClient1, kDevPassword);
  final pickup = DateTime.now()
      .toUtc()
      .add(const Duration(hours: 2))
      .toIso8601String();
  await http.post(
    Uri.parse('$kApiBaseUrl/rides'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $clientToken',
    },
    body: jsonEncode({
      'clientId': bmwClientId,
      'creatorId': bmwClientId,
      'clientName': 'BMW AG - Herr Schneider',
      'pickupDateTime': pickup,
      'from': {'address': 'Marienplatz, München'},
      'to': {'address': dropoff},
    }),
  );
}

void main() {
  patrolTest('dispatcher sees a newly booked ride appear live in Pending', (
    $,
  ) async {
    await resetTestData();

    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Make sure we're on the Pending list.
    await tapNav($, 'Pending');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // Create a ride from "another session" while the dispatcher is watching.
    await _createRideWithDropoff(_uniqueDropoff);

    // It should appear live, without a manual pull-to-refresh.
    await $(
      _uniqueDropoff,
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    expect($(_uniqueDropoff), findsWidgets);
  });
}
