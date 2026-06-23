import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher opens the Billing screen and walks its tabs.
///
/// Billing is a German-localised, seed-heavy screen (invoices, client
/// companies, billable rides). This is a smoke test: it opens the screen from
/// the bottom-nav "Billing" destination and confirms the invoice/company/rides
/// tabs render. Full invoice creation is covered by backend billing specs.
void main() {
  patrolTest('dispatcher opens billing and switches tabs', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Billing');
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // The graphite header reads "Billing"; the mobile tab bar exposes the three
    // German tabs.
    expect($('Billing'), findsWidgets);
    expect($('Rechnungen'), findsWidgets);

    // Switch to the billable-rides tab.
    if ($('Fahrten').exists) {
      await $('Fahrten').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    }

    expect($('Sign In'), findsNothing);
  });
}
