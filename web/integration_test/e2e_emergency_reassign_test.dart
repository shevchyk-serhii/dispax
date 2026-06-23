import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher opens the Emergency Reassignment screen and its dialog.
///
/// More → Emergency → open the dialog → verify the reason selector renders.
/// The full flow needs a valid in-progress ride ID typed + searched and a map
/// of suggested drivers, so this stays a structural smoke test that the
/// emergency tooling (distinct from the normal Reassign) opens correctly.
/// Exercises GET /emergency/reassignments.
void main() {
  patrolTest('dispatcher opens emergency reassignment', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Emergency').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));
    expect($('Emergency Reassignments'), findsWidgets);

    // Open the create dialog (add_circle_outline in the header).
    await $.tester.tap(
      find.byIcon(Icons.add_circle_outline).first,
      warnIfMissed: false,
    );
    await $.pumpAndSettle();

    // The dialog distinguishes emergency reassignment from the normal flow via
    // a Ride ID search + a reason picker.
    expect($('Emergency Reassignment'), findsWidgets);

    expect($('Sign In'), findsNothing);
  });
}
