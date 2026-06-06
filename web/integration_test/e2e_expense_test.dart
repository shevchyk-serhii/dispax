import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher logs an expense: More → Expenses → "+" → Log Expense dialog
/// (Category dropdown + Amount + Description) → Save. Exercises POST /expenses.
void main() {
  patrolTest('dispatcher logs an expense', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Expenses').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // Open the Log Expense dialog via the add action in the header.
    await $(Icons.add_circle_outline).tap();
    await $.pumpAndSettle();
    expect($('Log Expense'), findsWidgets);

    // Amount + Description are the dialog's two TextFields (Category is a
    // dropdown with a default value).
    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await $.tester.enterText(dialogFields.at(0), '42.50');
    await $.tester.enterText(dialogFields.at(1), 'E2E test fuel');
    await $.pumpAndSettle();

    await $.tester.tap(
      find.widgetWithText(FilledButton, 'Save'),
      warnIfMissed: false,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    expect($('Log Expense'), findsNothing);
    expect($('Sign In'), findsNothing);
  });
}
