import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher happy-path: walk the dashboard — Pending/Assigned lists, Schedule,
/// Analytics, and several More-menu sections. Opening the create-ride form is
/// verified too. The end-to-end driver assignment flow lives in
/// e2e_full_flow_test (which seeds a fresh Requested ride first).
void main() {
  patrolTest('dispatcher navigates the full dashboard', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Home → Pending / Assigned tabs.
    await tapNav($, 'Home');
    if (find.text('Pending').evaluate().isNotEmpty) {
      await tapNav($, 'Pending');
    }
    if (find.text('Assigned').evaluate().isNotEmpty) {
      await tapNav($, 'Assigned');
    }

    // Schedule + Analytics panels.
    await tapNav($, 'Schedule');
    await tapNav($, 'Analytics');

    // New Ride tab — verify the create form opens, then back out.
    await tapNav($, 'New Ride');
    expect($('Create Ride'), findsWidgets);
    if ($(BackButton).exists) {
      await $(BackButton).tap();
      await $.pumpAndSettle();
    }

    // More menu → open a few sections, returning each time via the AppBar back.
    await tapNav($, 'More');
    for (final section in ['Earnings', 'Drivers', 'Ratings', 'Audit Log']) {
      if (find.text(section).evaluate().isNotEmpty) {
        await tapNav($, section);
        if ($(BackButton).exists) {
          await $(BackButton).tap();
          await $.pumpAndSettle();
        }
      }
    }

    expect($('Sign In'), findsNothing);
  });
}
