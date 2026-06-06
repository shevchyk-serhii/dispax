import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Negative: submitting the create-ride form with empty pickup/drop-off must be
/// blocked by field validation — no ride is created and we stay on the form.
void main() {
  patrolTest('create ride form rejects empty input', ($) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Book');

    // Submit with empty From/To → field validators fire and block the submit.
    await $('Create Ride').scrollTo().tap();
    await $.pumpAndSettle();
    expect($('Pick-up location is required'), findsWidgets);
    expect($('Drop-off location is required'), findsWidgets);

    // Still on the form (no navigation / no success snackbar).
    expect($('Create Ride'), findsWidgets);
  });
}
