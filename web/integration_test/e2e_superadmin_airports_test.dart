import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// SuperAdmin airport exits & wait buffers smoke.
///
/// Logs in as superadmin, switches to the Airport Exits tab, and verifies the
/// airport/checkpoint configuration screen renders (GET /superadmin/airports).
/// The create flow uses a map picker (PlatformView), so this stays a smoke test
/// that confirms the screen and its "+ Airport" action are present.
void main() {
  patrolTest('superadmin opens airport exits config', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevSuperAdmin, kDevPassword);
    if (skipIfBackendDown($)) return;

    await $(
      'Airport Exits',
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    await tapNav($, 'Airport Exits');
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // Header + create action confirm the screen rendered without crashing.
    expect($('MUC exits & wait buffers'), findsWidgets);
    expect($('+ Airport'), findsWidgets);

    expect($('Sign In'), findsNothing);
  });
}
