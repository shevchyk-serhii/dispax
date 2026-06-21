import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// NEGATIVE: the SuperAdmin "Onboard Company" dialog rejects an empty form.
///
/// Login as superadmin → "+ Onboard" → submit blank. The required fields
/// (Company Name / Email / Phone / Address) show "Required" and the dialog
/// stays open — no tenant is created.
void main() {
  patrolTest('onboard company rejects an empty form', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevSuperAdmin, kDevPassword);
    if (skipIfBackendDown($)) return;

    await $('Tenants').waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('+ Onboard').tap();
    await $.pumpAndSettle();
    expect($('Onboard Company'), findsWidgets);

    // Submit with all fields blank.
    await $.tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Create'),
      ),
      warnIfMissed: false,
    );
    await $.pumpAndSettle();

    // Validators fire and the dialog stays open.
    expect($('Required'), findsWidgets);
    expect($('Onboard Company'), findsWidgets);

    expect($('Sign In'), findsNothing);
  });
}
