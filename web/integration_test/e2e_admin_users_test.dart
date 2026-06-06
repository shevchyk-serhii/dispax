import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Admin creates a new user: More → Admin → User Management → "+" → fill the
/// Create User form (Name/Email/Password/Role) → Create. Exercises POST /users.
void main() {
  patrolTest('admin creates a new user', ($) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevAdmin, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Open the Admin (User Management) screen from the More menu.
    await tapNav($, 'More');
    await $('Admin').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect($('User Management'), findsWidgets);

    // Open the Create User dialog via the person_add action in the header.
    await $(Icons.person_add).tap();
    await $.pumpAndSettle();
    expect($('Create User'), findsWidgets);

    // Fill the form. The screen also has a search TextField behind the dialog,
    // so scope the finders to the dialog's own fields. Unique email avoids
    // collisions across re-runs.
    final email = 'e2e_${DateTime.now().millisecondsSinceEpoch}@test.de';
    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await $.tester.enterText(dialogFields.at(0), 'E2E Test User');
    await $.tester.enterText(dialogFields.at(1), email);
    // Backend requires a strong password (8+ chars, upper, lower, digit).
    await $.tester.enterText(dialogFields.at(2), 'Password123');
    await $.pumpAndSettle();

    // Submit.
    await $.tester.tap(
      find.widgetWithText(ElevatedButton, 'Create'),
      warnIfMissed: false,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // Dialog closed → user created (or list refreshed).
    expect($('Create User'), findsNothing);
    expect($('Sign In'), findsNothing);
  });
}
