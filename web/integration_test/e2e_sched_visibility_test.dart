import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Covers the dispatcher "Sched. Visibility" (Who-can-see-whom) screen — the
/// one More-menu section the broad e2e_more_menu smoke test omits.
///
/// A dispatcher opens More → "Sched. Visibility", the screen renders the list
/// of company drivers, and toggling a driver's visibility Switch persists
/// without crashing. The screen swaps the dashboard body in-place (it does not
/// push a route), so we return by re-opening the "More" grid rather than via a
/// back button.
void main() {
  patrolTest('dispatcher toggles a driver schedule-visibility switch', (
    $,
  ) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Open More → Sched. Visibility.
    await tapNav($, 'More');
    await $('Sched. Visibility').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));

    // The screen header renders and the seeded company drivers load.
    await $(
      'Who can see whom',
    ).waitUntilVisible(timeout: const Duration(seconds: 12));

    // Seeded dev data has two drivers (Hans Weber / driver1, driver2). At least
    // one visibility Switch must be present to toggle. `Switch.adaptive` renders
    // a material Switch on Android and a CupertinoSwitch on iOS — match either.
    final switches = find.byWidgetPredicate(
      (w) => w is Switch || w is CupertinoSwitch,
    );
    expect(
      switches,
      findsWidgets,
      reason: 'driver visibility rows should each carry a Switch',
    );

    // Toggle the first driver's visibility. The change is sent to the backend
    // via the schedule service; the screen must not crash and must stay open.
    await $.tester.tap(switches.first, warnIfMissed: false);
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));

    // Still on the visibility screen (no error dialog / route pop), and not
    // bounced back to login.
    expect($('Who can see whom'), findsWidgets);
    expect($('Sign In'), findsNothing);
  });
}
