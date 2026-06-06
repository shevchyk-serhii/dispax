import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Secretary happy-path: log in, open the create-ride form from the Home tab,
/// then visit Reports and Settings. Creating a ride as a secretary requires
/// picking a client through a backend-backed autocomplete; the actual ride
/// creation + assignment is covered end-to-end by e2e_full_flow_test, so here
/// we verify the form opens and the navigation works.
void main() {
  patrolTest('secretary opens create form and views reports', ($) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevSecretary, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Home tab shows the "Start Creating" entry point.
    expect($('Create New Ride'), findsWidgets);
    await $('Start Creating').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // The create-ride form is shown (From/To fields + Create Ride button).
    expect($('Create Ride'), findsWidgets);
    expect($(TextFormField), findsWidgets);

    // Close the form and return to the dashboard.
    if ($(BackButton).exists) {
      await $(BackButton).tap();
      await $.pumpAndSettle();
    }

    // Reports + Settings tabs.
    await tapNav($, 'Rides');
    await tapNav($, 'Settings');
    await tapNav($, 'Home');

    expect($('Sign In'), findsNothing);
  });
}
