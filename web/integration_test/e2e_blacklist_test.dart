import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher adds a blacklist entry: More → Blacklist → "+" → Add Blacklist
/// Entry dialog (Client ID + Driver ID + Reason) → Add. Exercises POST /blacklist.
/// Uses real dev-data IDs (client BMW = 6666…, driver Hans = 3333…).
void main() {
  patrolTest('dispatcher adds a blacklist entry', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Blacklist').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await $(Icons.add_circle_outline).tap();
    await $.pumpAndSettle();
    expect($('Add Blacklist Entry'), findsWidgets);

    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await $.tester.enterText(
      dialogFields.at(0),
      '66666666-6666-6666-6666-666666666666',
    );
    await $.tester.enterText(
      dialogFields.at(1),
      '33333333-3333-3333-3333-333333333333',
    );
    await $.tester.enterText(dialogFields.at(2), 'E2E test reason');
    await $.pumpAndSettle();

    await $.tester.tap(
      find.widgetWithText(FilledButton, 'Add'),
      warnIfMissed: false,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    expect($('Add Blacklist Entry'), findsNothing);
    expect($('Sign In'), findsNothing);
  });
}
