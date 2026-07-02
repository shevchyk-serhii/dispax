import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Regression e2e for the "Navigate to" dialog being impossible to dismiss on
/// iOS (Cupertino-style adaptive dialog whose outside-tap barrier is ignored,
/// with no Cancel option). The fix adds an explicit "Cancel" option.
///
/// Flow: seed an assigned ride for driver Hans (driver1) on today via HTTP, log
/// in as the driver, open the live ride card's "Navigate" picker, tap "Cancel",
/// and assert the dialog closes (and we stay on the dashboard — Google Maps is
/// not launched).
void main() {
  patrolTest('Navigate to dialog can be dismissed via Cancel', ($) async {
    await resetTestData();

    // Seed an assigned ride so the driver lands on a live ride card that
    // exposes the "Navigate" action.
    final clientToken = await apiLogin(kDevClient1, kDevPassword);
    final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
    final rideId = await createRideId(
      clientToken,
      pickupDateTime: pickupAt(const Duration(hours: 2)),
    );
    await assignDriver(rideId, dispatcherToken);

    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // The assigned ride renders a live card with a "Navigate" action.
    //
    // NB: the driver Today screen runs a never-ending pulse animation (the live
    // green dot), so pumpAndSettle never returns here — use fixed pumps and
    // waitUntilVisible/waitUntilExists instead.
    await $('Navigate').waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Navigate').scrollTo().tap();
    await $.pump(const Duration(milliseconds: 500));

    // The "Navigate to" picker is open.
    await $('Navigate to').waitUntilVisible(
      timeout: const Duration(seconds: 10),
    );
    expect($('Navigate to'), findsWidgets);

    // Tap the Cancel option inside the dialog (scoped to the SimpleDialog so we
    // don't hit any other "Cancel" on the screen). This is the fix under test.
    final cancelInDialog = find.descendant(
      of: find.byType(SimpleDialog),
      matching: find.text('Cancel'),
    );
    expect(cancelInDialog, findsOneWidget);
    await $.tester.tap(cancelInDialog, warnIfMissed: false);
    await $.pump(const Duration(milliseconds: 500));

    // Dialog is gone and we are still on the driver dashboard.
    expect($('Navigate to'), findsNothing);
    expect($('Sign In'), findsNothing);
  });
}
