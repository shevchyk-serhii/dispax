import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher creates a recurring ride template.
///
/// More → Templates → add → fill the Create Template form (Client dropdown +
/// Name/From/To/Pickup Time; Recurrence keeps its "Daily" default) → Create.
/// Exercises GET /users/clients and POST /ride-templates.
///
/// Field order within the dialog's TextFields (the Client/Recurrence dropdowns
/// are DropdownButtonFormField, not TextField, so they don't shift the index):
///   0 Template Name · 1 From Address · 2 To Address · 3 Pickup Time · 4 Notes · 5 Price
void main() {
  patrolTest('dispatcher creates a ride template', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Templates').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect($('Saved templates'), findsWidgets);

    // The header add icon and the empty-state add button both use Icons.add;
    // tap the first (header) to open the Create Template dialog.
    await $.tester.tap(find.byIcon(Icons.add).first, warnIfMissed: false);
    await $.pumpAndSettle();
    expect($('Create Template'), findsWidgets);

    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await $.tester.enterText(dialogFields.at(0), 'E2E Morning Transfer');
    await $.tester.enterText(dialogFields.at(1), 'Marienplatz, München');
    await $.tester.enterText(dialogFields.at(2), 'Flughafen München');
    await $.tester.enterText(dialogFields.at(3), '08:30');
    await $.pumpAndSettle();

    // Client is a required dropdown with no default — open it and pick the
    // first seeded client (BMW / Siemens / Allianz from V1001).
    await $.tester.tap(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField).first,
      warnIfMissed: false,
    );
    await $.pumpAndSettle();
    // Tap the first dropdown menu item that appears in the overlay.
    final menuItem = find.byType(DropdownMenuItem).first;
    if (menuItem.evaluate().isNotEmpty) {
      await $.tester.tap(menuItem, warnIfMissed: false);
      await $.pumpAndSettle();
    }

    await $.tester.tap(
      find.widgetWithText(ElevatedButton, 'Create'),
      warnIfMissed: false,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    expect($('Sign In'), findsNothing);
  });
}
