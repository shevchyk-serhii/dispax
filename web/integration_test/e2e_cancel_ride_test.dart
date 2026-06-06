import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Client cancels an active ride: create a ride, then cancel it from the Home
/// tab via the inline "Cancel" button → CancelRideDialog (pick a reason →
/// "Cancel Ride"). Exercises Requested → Cancelled.
void main() {
  patrolTest('client creates then cancels a ride', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Create a ride.
    await tapNav($, 'Book');
    await $(TextFormField).at(0).enterText('Marienplatz, München');
    await $(TextFormField).at(1).enterText('Hauptbahnhof, München');
    await $.pumpAndSettle();
    await $('Create Ride').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    // Back on Home, the active ride shows a "Cancel" button.
    await tapNav($, 'Home');
    await $('Cancel').waitUntilVisible(timeout: const Duration(seconds: 15));
    await $('Cancel').tap();
    await $.pumpAndSettle();

    // CancelRideDialog: select a reason from the dropdown. The dropdown opens
    // an overlay; let Patrol wait for the option to become visible.
    expect($('Please select a reason for cancellation:'), findsWidgets);
    await $(DropdownButtonFormField<String>).tap();
    await $.pumpAndSettle();
    await $('Client Request').tap();
    await $.pumpAndSettle();

    // Confirm. "Cancel Ride" appears twice (dialog title + button); tap the
    // ElevatedButton specifically, which is enabled once a reason is selected.
    await $.tester.tap(
      find.widgetWithText(ElevatedButton, 'Cancel Ride'),
      warnIfMissed: false,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // The dialog closed → cancellation submitted.
    expect($('Please select a reason for cancellation:'), findsNothing);
    expect($('Sign In'), findsNothing);
  });
}
