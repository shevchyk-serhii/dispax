import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Client happy-path: log in, create a ride via the Book tab, then walk the
/// remaining navigation tabs. Runs against the full backend (dev-data) on
/// TEST_PORT. The pickup time defaults to now()+1h, so no native date/time
/// picker interaction is needed.
void main() {
  patrolTest('client creates a ride and navigates all tabs', ($) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Book tab → fill From/To → Create Ride.
    await tapNav($, 'Book');
    expect($('From'), findsWidgets);
    await $(TextFormField).at(0).enterText('Marienplatz, München');
    await $(TextFormField).at(1).enterText('Flughafen München');
    await $.pumpAndSettle();

    await $('Create Ride').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    // Ride created — confirmation SnackBar or return to the list.
    // (SnackBar may auto-dismiss; we don't hard-assert on it.)

    // Walk the remaining tabs; assert each screen opens without crashing.
    // Visit Map last — its Mapbox PlatformView can shadow the bottom nav's
    // hit-testing, so we don't navigate away from it.
    await tapNav($, 'Rides');
    await tapNav($, 'Settings');
    await tapNav($, 'Home');
    expect($('Sign In'), findsNothing);
    await tapNav($, 'Map');
  });
}
