import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// SuperAdmin platform analytics smoke.
///
/// Logs in as superadmin, switches to the Analytics tab, and verifies the
/// cross-tenant platform metrics render (GET /superadmin/analytics). The tile
/// labels are static; their values are data-driven, so we assert the labels.
void main() {
  patrolTest('superadmin views platform analytics', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevSuperAdmin, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Switch to the Analytics destination in the SuperAdmin dashboard.
    await $('Analytics').waitUntilVisible(timeout: const Duration(seconds: 20));
    await tapNav($, 'Analytics');
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // The platform analytics screen renders its header and stat tiles.
    expect($('Platform Analytics'), findsWidgets);
    expect($('Total Rides'), findsWidgets);

    expect($('Sign In'), findsNothing);
  });
}
