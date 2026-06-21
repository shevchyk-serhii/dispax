import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// NEGATIVE (tenant isolation): a dispatcher only sees their own company's
/// rides.
///
/// The Company 1 dispatcher (dispatcher@dispax.de) opens the Pending/Assigned
/// board. The backend scopes every ride query by the JWT companyId, so Company
/// 2 (Taxi Schwabing) rides — e.g. the "Schwabing Markt" pickup and the Audi
/// client — must not appear on either tab.
void main() {
  patrolTest('dispatcher does not see another company\'s rides', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Home');
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // Check both tabs for foreign-tenant leakage.
    for (final tab in const ['Pending', 'Assigned']) {
      if ($(tab).exists) {
        await $(tab).tap();
        await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      }
      expect(
        find.textContaining('Schwabing Markt'),
        findsNothing,
        reason: 'Company 2 ride must not appear on the $tab tab',
      );
      expect(
        find.textContaining('Audi'),
        findsNothing,
        reason: 'Company 2 client must not appear on the $tab tab',
      );
    }

    expect($('Sign In'), findsNothing);
  });
}
