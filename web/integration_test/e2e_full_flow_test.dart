import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// End-to-end ride lifecycle across three roles in a single test:
///   Client creates → Dispatcher assigns a driver → Driver Starts → Completes.
/// Exercises the full status machine Requested → Assigned → InProgress → Completed.
///
/// Relies on seeded driver schedules (schedule_days for today) so the
/// dispatcher can assign. Driver "Hans Weber" = driver1@dispax.de.
void main() {
  patrolTest('full ride lifecycle: client → dispatcher → driver', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    // 1) Client creates a ride.
    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Book');
    await $(TextFormField).at(0).enterText('Maximilianstraße 10, München');
    await $(TextFormField).at(1).enterText('Flughafen München Terminal 2');
    await $.pumpAndSettle();
    await $('Create Ride').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    // The "Ride created successfully!" SnackBar overlaps the bottom nav; wait
    // for it to dismiss before navigating.
    await $.pump(const Duration(seconds: 5));
    await $.pumpAndSettle();

    // Return to the Home tab to ensure the dashboard (with the bottom nav) is
    // shown before logging out.
    await tapNav($, 'Home');
    await logoutViaUi($);

    // 2) Dispatcher assigns the ride to a driver.
    await loginViaUi($, kDevDispatcher, kDevPassword);
    await tapNav($, 'Home');
    if ($('Pending').exists) {
      await $('Pending').tap();
      await $.pumpAndSettle();
    }

    // The pending list loads from the backend asynchronously — wait for the
    // ride card to appear before tapping it to open the "Select Driver" sheet.
    await $(
      'Flughafen München Terminal 2',
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Flughafen München Terminal 2').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect($('Select Driver'), findsWidgets);

    // Pick driver "Hans Weber" (driver1) and confirm the assignment.
    await $('Hans Weber').scrollTo().tap();
    await $.pumpAndSettle();
    if ($('Assign').exists || $('Assign Anyway').exists) {
      await ($('Assign Anyway').exists ? $('Assign Anyway') : $('Assign'))
          .tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 20));
    }

    await logoutViaUi($);

    // 3) Driver starts and completes the ride.
    await loginViaUi($, kDevDriver1, kDevPassword);
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // Assigned ride shows on Today with a "Start" action.
    await $('Start').waitUntilVisible(timeout: const Duration(seconds: 15));
    await $('Start').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // InProgress ride shows "Complete" → opens the "Complete Ride" dialog whose
    // confirm button is also labelled "Complete".
    await $('Complete').waitUntilVisible(timeout: const Duration(seconds: 15));
    await $('Complete').scrollTo().tap();
    await $.pumpAndSettle();
    await $(
      'Complete Ride',
    ).waitUntilVisible(timeout: const Duration(seconds: 10));
    await $('Complete').last.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // Settle the "Ride completed" SnackBar and return to a stable tab before
    // logging out.
    await $.pump(const Duration(seconds: 3));
    await tapNav($, 'Today');
    await logoutViaUi($);

    // 4) Client rates the completed ride from the Rides (history) tab, where
    // each completed card has an inline "Rate this ride" button.
    await loginViaUi($, kDevClient1, kDevPassword);
    await tapNav($, 'Rides');
    await $(
      'Rate this ride',
    ).waitUntilVisible(timeout: const Duration(seconds: 15));
    await $('Rate this ride').scrollTo().tap();
    await $.pumpAndSettle();

    // RateRideDialog: tap the 5th star inside the dialog, then Submit (enabled
    // once rating > 0). Scope the star finder to the dialog so it doesn't match
    // rating stars rendered behind it.
    expect($('Rate Your Ride'), findsWidgets);
    // The 5 stars are IconButtons; tap the last one (5-star rating). Tapping the
    // IconButton (not its Icon) reliably triggers onPressed.
    final starButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(IconButton),
    );
    await $.tester.tap(starButtons.last, warnIfMissed: false);
    await $.pumpAndSettle();
    await $.tester.tap(
      find.widgetWithText(ElevatedButton, 'Submit'),
      warnIfMissed: false,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    expect($('Sign In'), findsNothing);
  });
}
