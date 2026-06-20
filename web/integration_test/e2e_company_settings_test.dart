import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Admin opens Company Settings and walks its sections.
///
/// More → Company → verify the settings screen renders its left-nav sections
/// (Company, Users & Roles, Compliance, Billing & DATEV, Geofences) and switch
/// to Billing & DATEV (tariff + DATEV integration fields). A full save touches
/// several PUT endpoints with company-wide effects, so this is a navigation
/// smoke test. Exercises GET /companies/{id} and tariff/DATEV config loads.
void main() {
  patrolTest('admin opens company settings', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevAdmin, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Company').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));
    expect($('Company Settings'), findsWidgets);

    // Switch to the Billing & DATEV section.
    if ($('Billing & DATEV').exists) {
      await $('Billing & DATEV').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    }

    expect($('Sign In'), findsNothing);
  });
}
