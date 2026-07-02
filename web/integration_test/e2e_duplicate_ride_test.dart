import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Dispatcher duplicates an existing ride via the ride-details "Duplicate"
/// button (RideActionsCard) → NavigationUtils.duplicateRide opens a prefilled
/// CreateRideScreen (FormPrefilledFromRide). The Duplicate button on the
/// pending-row panel is icon-only with no text label, so this exercises the
/// same NavigationUtils.duplicateRide path via the details screen, where the
/// button carries a visible "Duplicate" label.
///
/// Only unit/widget tests cover the form-prefill mapping today (per
/// FormPrefilledFromRide's own history) — nothing exercises the real UI path:
/// tap Duplicate → the create form actually opens pre-filled → submitting it
/// creates a second, independent Requested ride.
void main() {
  patrolTest('dispatcher duplicates a ride into a new request', ($) async {
    await resetTestData();
    final clientToken = await apiLogin(kDevClient1, kDevPassword);
    final originalRideId = await createRideId(clientToken);

    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Home');
    if ($('Pending').exists) {
      await $('Pending').tap();
      // The dashboard behind this screen runs a perpetual animation, so
      // pumpAndSettle never settles here — use bounded pumps instead,
      // matching patrol_helpers.dart's tapNav pattern.
      await $.pump(const Duration(milliseconds: 300));
      await $.pump(const Duration(milliseconds: 300));
    }

    // Open the ride's details screen via the info icon. Its "Details" label is
    // a tooltip only (shown on long-press/hover), not rendered text, so
    // $('Details') never matches — tap the icon itself instead.
    await $(
      'Flughafen München',
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    await $.tester.tap(
      find.byIcon(Icons.info_outline).first,
      warnIfMissed: false,
    );
    // The details screen opens via a Hero transition — pump through it in
    // bounded steps rather than pumpAndSettle (which never settles on this
    // screen), long enough for the transition to actually finish.
    for (var i = 0; i < 5; i++) {
      await $.pump(const Duration(milliseconds: 300));
    }

    // "Duplicate" exists in the tree but isn't hit-testable until scrolled
    // into view — scrollTo() (not waitUntilVisible) is what actually reveals
    // it on this screen.
    await $('Duplicate').scrollTo().tap();
    await $.pump(const Duration(milliseconds: 300));
    await $.pump(const Duration(milliseconds: 300));

    // The prefilled create form opened with the original pickup address.
    expect($('Create New Ride'), findsWidgets);
    expect($('Marienplatz, München'), findsWidgets);

    // Submit the prefilled form as-is.
    await $('Create Ride').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));
    await $.pump(const Duration(seconds: 3));

    // Backend-level assertion: a second Requested ride now exists alongside
    // the original (Duplicate must not mutate/replace the source ride).
    final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
    final originalStatus = await rideStatus(originalRideId, dispatcherToken);
    expect(
      originalStatus,
      equals('Requested'),
      reason: 'duplicating must not change the original ride',
    );

    final pending = await apiGet('/rides/pending', dispatcherToken);
    final pendingIds = (pending.body as List)
        .map((r) => (r as Map<String, dynamic>)['id'] as String)
        .toList();
    expect(
      pendingIds.where((id) => id != originalRideId).length,
      greaterThanOrEqualTo(1),
      reason: 'a duplicated ride should create a second, independent request',
    );
  });
}
