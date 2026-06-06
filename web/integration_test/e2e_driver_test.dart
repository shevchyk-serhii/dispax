import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Driver happy-path: log in, toggle availability, walk all tabs, create a ride
/// from the Book tab. Status transitions (Start/Complete) are covered by
/// e2e_full_flow_test, which sets up an assigned ride first.
void main() {
  patrolTest('driver navigates dashboard and creates a ride', ($) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Today tab is the default landing screen for drivers.
    expect($('Sign In'), findsNothing);

    // Toggle availability if the switch is present.
    if ($('Available').exists || $('Offline').exists) {
      await $(Switch).tap();
      await $.pumpAndSettle();
    }

    // Calendar tab.
    await tapNav($, 'Calendar');

    // Book tab → create a ride (driver books for a client).
    await tapNav($, 'Book');
    await $(TextFormField).at(0).enterText('Hauptbahnhof, München');
    await $(TextFormField).at(1).enterText('Marienplatz, München');
    await $.pumpAndSettle();
    await $('Create Ride').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    // Remaining tabs. Visit Map last — its full-screen Mapbox PlatformView can
    // shadow the bottom nav's hit-testing, so we don't navigate away from it.
    await tapNav($, 'Settings');
    await tapNav($, 'Today');
    await tapNav($, 'Map');

    expect($('Sign In'), findsNothing);
  });
}
