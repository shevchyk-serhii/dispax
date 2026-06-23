import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// NEGATIVE (tenant isolation): a driver never sees another company's rides.
///
/// Hans (driver1@dispax.de) belongs to Company 1 (Dispax München). The V1001
/// dev data also seeds Company 2 (Taxi Schwabing) rides for Maria, including a
/// "Schwabing Markt, München" → "Marienplatz" ride. When Hans opens his Today
/// list, the backend filters by his JWT companyId, so Company 2 addresses must
/// not appear anywhere in his UI.
void main() {
  patrolTest('driver does not see another company\'s rides', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Driver lands on the Today rides list.
    await tapNav($, 'Today');
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // Company 2 (Taxi Schwabing) ride markers must never leak into Company 1's
    // driver view.
    expect(
      find.textContaining('Schwabing Markt'),
      findsNothing,
      reason: 'Company 2 ride pickup must not appear for a Company 1 driver',
    );
    expect(
      find.textContaining('Audi'),
      findsNothing,
      reason:
          'Company 2 client (Audi AG) must not appear for a Company 1 driver',
    );

    expect($('Sign In'), findsNothing);
  });
}
