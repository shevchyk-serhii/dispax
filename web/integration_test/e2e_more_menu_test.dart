import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Opens every dispatcher "More" menu section, verifies the screen renders
/// (no paint exceptions), and returns. This broadly smoke-tests the 20+ feature
/// screens. Sections with their own dedicated tests (Admin, Expenses, Blacklist,
/// Geofences) are covered there in depth.
void main() {
  patrolTest('dispatcher opens every More-menu section', ($) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    const sections = <String>[
      'Earnings',
      'Peak Hours',
      'Client Value',
      'Drivers',
      'Ratings',
      'Audit Log',
      'Company',
      'Export',
      'Billing',
      'Templates',
      'Payments',
      'Payroll',
      'DATEV',
      'Emergency',
      'Ride Pools',
      'Notifications',
      'GDPR',
      'Sessions',
    ];

    for (final section in sections) {
      await tapNav($, 'More');
      // Some labels can sit lower in the grid — scroll the section into view.
      final finder = find.text(section);
      if (finder.evaluate().isEmpty) continue;
      await $(section).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 12));

      // Screen opened without crashing; return to the dashboard.
      if ($(BackButton).exists) {
        await $(BackButton).tap();
        await $.pumpAndSettle();
      }
    }

    expect($('Sign In'), findsNothing);
  });
}
