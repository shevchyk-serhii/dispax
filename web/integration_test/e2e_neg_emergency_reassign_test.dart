import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// NEGATIVE: emergency reassignment rejects a submit with no Ride ID.
///
/// More → Emergency → open the dialog → submit without entering a Ride ID.
/// The screen shows the "Ride ID is required" SnackBar and the dialog stays
/// open — no reassignment is attempted.
void main() {
  patrolTest('emergency reassignment requires a ride id', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Emergency').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));
    expect($('Emergency Reassignments'), findsWidgets);

    await $.tester.tap(
      find.byIcon(Icons.add_circle_outline).first,
      warnIfMissed: false,
    );
    await $.pumpAndSettle();
    expect($('Emergency Reassignment'), findsWidgets);

    // Submit with an empty Ride ID — the FilledButton labelled "Reassign".
    await $.tester.tap(
      find.widgetWithText(FilledButton, 'Reassign'),
      warnIfMissed: false,
    );
    await $.pumpAndSettle();

    // The required-field guard fires.
    expect($('Ride ID is required'), findsWidgets);

    expect($('Sign In'), findsNothing);
  });
}
