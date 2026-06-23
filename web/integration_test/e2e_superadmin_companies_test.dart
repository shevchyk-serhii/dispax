import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// SuperAdmin onboards a new tenant company.
///
/// Logs in as superadmin (lands on the Companies tab), opens the "+ Onboard"
/// dialog, fills the company form, and submits. Exercises the cross-tenant
/// SuperAdmin dashboard and POST /superadmin/companies.
void main() {
  patrolTest('superadmin onboards a company', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevSuperAdmin, kDevPassword);
    if (skipIfBackendDown($)) return;

    // SuperAdmin lands on the Companies tab. The graphite header reads
    // "Tenants · N companies".
    await $('Tenants').waitUntilVisible(timeout: const Duration(seconds: 20));

    // Open the onboard dialog.
    await $('+ Onboard').tap();
    await $.pumpAndSettle();
    expect($('Onboard Company'), findsWidgets);

    // Fill the form fields (scoped to the dialog). Order in the form:
    // Name, Email, Phone, Address.
    final unique = DateTime.now().millisecondsSinceEpoch;
    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await $.tester.enterText(dialogFields.at(0), 'E2E Tenant $unique');
    await $.tester.enterText(dialogFields.at(1), 'tenant$unique@e2e.de');
    await $.tester.enterText(dialogFields.at(2), '+49 89 1234567');
    await $.tester.enterText(dialogFields.at(3), 'Teststraße 1, München');
    await $.pumpAndSettle();

    // Submit ("Create" for a new company).
    await $.tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Create'),
      ),
      warnIfMissed: false,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // Dialog closed → company created (or list refreshed).
    expect($('Onboard Company'), findsNothing);
    expect($('Sign In'), findsNothing);
  });
}
