import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Admin happy-path: admins share the dispatcher dashboard. Log in and open a
/// few admin-oriented sections from the More menu.
void main() {
  patrolTest('admin navigates dashboard and admin sections', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevAdmin, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Dispatcher dashboard is shown for admins too.
    await tapNav($, 'Analytics');
    await tapNav($, 'More');

    for (final section in [
      'Admin',
      'Company',
      'GDPR',
      'Sessions',
      'Audit Log',
    ]) {
      if ($(section).exists) {
        await $(section).tap();
        await $.pumpAndSettle(timeout: const Duration(seconds: 10));
        if ($(BackButton).exists) {
          await $(BackButton).tap();
          await $.pumpAndSettle();
        }
      }
    }

    expect($('Sign In'), findsNothing);
  });
}
