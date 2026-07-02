import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Secretary books a ride on behalf of a client end-to-end:
/// Create tab → pick a client via the "Client Name" autocomplete → fill
/// From/To → "Create Ride". Exercises the secretary create-ride flow that
/// e2e_secretary_test only smoke-tested (it just opened the form).
///
/// Asserts the REAL result, not just that the form closed: after submission we
/// confirm the backend has a fresh Requested ride for the BMW client (queried
/// over HTTP as the dispatcher), so the test goes red if the Create button is a
/// no-op or the ride never reaches the backend.
void main() {
  patrolTest('secretary creates a ride for a client', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    // Don't pumpAndSettle at boot: while auth state is restored the app may show
    // a spinner (CircularProgressIndicator), so settle can time out. Pump a few
    // bounded frames instead; loginViaUi then waits for the LoginScreen itself.
    for (var i = 0; i < 5; i++) {
      await $.pump(const Duration(milliseconds: 300));
    }

    // Baseline: how many Requested rides exist for the BMW client before we
    // create one (should be 0 after reset, but read it to be robust).
    final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
    final before = await _requestedRideCount(dispatcherToken);

    await loginViaUi($, kDevSecretary, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Open the Create tab (bottom-nav destination, index 2).
    await tapNav($, 'Create');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect($('Create New Ride'), findsWidgets);

    // Client autocomplete: type into the "Client Name" field, then tap the
    // matching suggestion tile. The dev-data client is "BMW AG - Herr Schneider".
    final clientField = find.widgetWithText(TextFormField, 'Client Name');
    expect(clientField, findsWidgets);
    await $.tester.enterText(clientField.first, 'BMW');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $(
      'BMW AG - Herr Schneider',
    ).waitUntilVisible(timeout: const Duration(seconds: 10));
    await $('BMW AG - Herr Schneider').tap();
    await $.pumpAndSettle();

    // From/To: the two address fields. After selecting a client the form shows
    // additional fields, so locate the pickup/dropoff inputs by their labels.
    final fromField = find.widgetWithText(TextFormField, 'From');
    final toField = find.widgetWithText(TextFormField, 'To');
    expect(fromField, findsWidgets);
    expect(toField, findsWidgets);
    await $.tester.enterText(fromField.first, 'Marienplatz, München');
    await $.tester.enterText(toField.first, 'Flughafen München');
    await $.pumpAndSettle();

    // Submit.
    await $('Create Ride').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    // Verify the ride actually landed in the backend (Requested, BMW client).
    // Poll briefly because creation is async.
    var after = before;
    for (var i = 0; i < 10 && after <= before; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      after = await _requestedRideCount(dispatcherToken);
    }
    expect(
      after,
      greaterThan(before),
      reason: 'Secretary create should add a Requested ride for the client',
    );
    expect($('Sign in'), findsNothing);
  });
}

/// Counts Requested rides belonging to the BMW client, as seen by the dispatcher.
Future<int> _requestedRideCount(String dispatcherToken) async {
  final res = await apiGet('/rides', dispatcherToken);
  final body = res.body;
  if (body is! List) return 0;
  return body.where((r) {
    if (r is! Map) return false;
    return r['status'] == 'Requested' && r['clientId'] == bmwClientId;
  }).length;
}
