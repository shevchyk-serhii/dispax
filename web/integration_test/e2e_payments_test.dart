import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher records a payment.
///
/// More → Payments → (if any unpaid ride is listed) Mark as Paid → choose a
/// payment method → Confirm Payment. The V1001 dev data seeds unpaid rides
/// (e.g. the in-progress BMW ride at €12.00). If the list is empty we still
/// assert the screen rendered. Exercises GET /rides/unpaid and
/// PUT /rides/{id}/payment.
void main() {
  patrolTest('dispatcher marks a ride as paid', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Payments').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));
    expect($('Payments'), findsWidgets);

    // If there's an unpaid ride, run the full mark-as-paid flow.
    if ($('Mark as Paid').exists) {
      await $('Mark as Paid').scrollTo().tap();
      await $.pumpAndSettle();

      // The dialog title is also "Mark as Paid"; pick a method then confirm.
      if ($('Card').exists) {
        await $('Card').tap();
        await $.pumpAndSettle();
      }
      await $('Confirm Payment').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));

      // Dialog closed.
      expect($('Confirm Payment'), findsNothing);
    }

    expect($('Sign In'), findsNothing);
  });
}
