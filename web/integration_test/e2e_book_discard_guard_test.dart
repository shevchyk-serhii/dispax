import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Regression: leaving the Book tab must only prompt "Discard changes?" when the
/// driver actually entered something. The form auto-preselects the current user
/// as both client and driver on open; that preselect must NOT count as a user
/// modification, otherwise the guard fires on every tab switch (the bug this
/// covers).
///
/// Two scenarios in one bundle (E2E runs as a single bundle, so we reset/login
/// once and keep both flows in the same test):
///  A. Open Book, enter nothing, switch tab → no dialog, navigation succeeds.
///  B. Open Book, type a From address, switch tab → dialog appears; "Stay"
///     keeps us on the form with the typed address intact.
void main() {
  patrolTest('Book tab discard guard only fires on real input', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // ---- Scenario A: pristine form must not prompt -------------------------
    await tapNav($, 'Book');
    await $.pumpAndSettle();

    // Leave immediately without touching anything.
    await tapNav($, 'Today');
    await $.pumpAndSettle();

    // The auto-preselect (self as client/driver) must not be treated as a
    // change, so no discard dialog should ever appear.
    expect(
      find.text('Discard changes?'),
      findsNothing,
      reason: 'Pristine form (only auto-preselect) must not trigger the guard',
    );

    // ---- Scenario B: real input must prompt, "Stay" keeps the form --------
    await tapNav($, 'Book');
    await $.pumpAndSettle();

    // Field order for a driver: [0] client search, [1] From address, [2] To
    // address. We type into the From address (index 1) — that is a tracked form
    // field, so it must flip isModified and arm the guard. (The client-search
    // field at index 0 is a local filter and intentionally does NOT count.)
    const fromAddress = 'Hauptbahnhof, München';
    await $(TextFormField).at(1).enterText(fromAddress);
    await $.pumpAndSettle();

    // Attempt to leave → the guard should now show the discard dialog.
    await tapNav($, 'Today');
    await $.pumpAndSettle();
    expect(
      find.text('Discard changes?'),
      findsOneWidget,
      reason: 'Form with user input must trigger the unsaved-changes guard',
    );

    // Choose "Stay" → dialog closes and we remain on the form with the address.
    await $.tester.tap(find.text('Stay'));
    await $.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect($(fromAddress), findsWidgets);
    expect($('Create Ride'), findsWidgets);
  });
}
