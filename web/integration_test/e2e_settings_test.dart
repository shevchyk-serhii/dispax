import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Settings happy-path: change the theme, open the Change Password dialog and
/// verify its fields, then open Active Sessions and Privacy (GDPR) screens.
void main() {
  patrolTest('client changes theme and opens account screens', ($) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Settings');
    await $('Theme').waitUntilVisible(timeout: const Duration(seconds: 10));

    // Change theme to Dark via the dropdown.
    await $('Theme').scrollTo();
    await $(DropdownButton<String>).at(0).tap();
    await $.pumpAndSettle();
    if (find.text('Dark').evaluate().isNotEmpty) {
      await $.tester.tap(find.text('Dark').last, warnIfMissed: false);
      await $.pumpAndSettle();
    }

    // Open Change Password dialog and verify its three fields.
    await $('Change Password').scrollTo().tap();
    await $.pumpAndSettle();
    expect($('Current Password'), findsWidgets);
    expect($('New Password'), findsWidgets);
    expect($('Confirm New Password'), findsWidgets);
    // Close the dialog.
    await $('Cancel').tap();
    await $.pumpAndSettle();

    // Open Active Sessions screen and go back.
    await $('Active Sessions').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    if ($(BackButton).exists) {
      await $(BackButton).tap();
      await $.pumpAndSettle();
    }

    // Open Privacy & Data (GDPR) screen.
    await $('Privacy & Data (GDPR)').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect($('CONSENT MANAGEMENT'), findsWidgets);

    expect($('Sign In'), findsNothing);
  });
}
