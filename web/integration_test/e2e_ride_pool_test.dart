import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher creates a ride pool.
///
/// More → Ride Pools → add → fill the Create Ride Pool dialog (optional Name +
/// Route Direction; Max Passengers keeps its default) → Create.
/// Exercises POST /ride-pools.
void main() {
  patrolTest('dispatcher creates a ride pool', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Ride Pools').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect($('Ride Pools'), findsWidgets);

    // Open the Create Ride Pool dialog (add_circle_outline in the header).
    await $.tester.tap(
      find.byIcon(Icons.add_circle_outline).first,
      warnIfMissed: false,
    );
    await $.pumpAndSettle();
    expect($('Create Ride Pool'), findsWidgets);

    // Both fields are optional; fill the name for a recognisable pool.
    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await $.tester.enterText(dialogFields.at(0), 'E2E Airport Shuttle');
    await $.tester.enterText(dialogFields.at(1), 'City Center → Airport');
    await $.pumpAndSettle();

    // Submit ("Create" FilledButton in the dialog actions).
    await $.tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Create'),
      ),
      warnIfMissed: false,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    expect($('Create Ride Pool'), findsNothing);
    expect($('Sign In'), findsNothing);
  });
}
