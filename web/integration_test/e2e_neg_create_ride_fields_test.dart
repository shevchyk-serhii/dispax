import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// NEGATIVE: the dispatcher's New Ride form rejects missing pickup/dropoff.
///
/// This complements e2e_neg_create_ride (client side) by exercising the
/// dispatcher's CreateRideScreen. Submitting with empty addresses surfaces the
/// field validators ("Pick-up location is required" / "Drop-off location is
/// required") and the form does not submit.
void main() {
  patrolTest('dispatcher new-ride form rejects empty locations', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'New Ride');
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));

    // Submit the form with everything blank. The primary action is the
    // create/submit button at the bottom of the form.
    if ($('Create Ride').exists) {
      await $('Create Ride').scrollTo().tap();
      await $.pumpAndSettle();
    }

    // Required-location validators must appear; the form must not navigate away
    // with a success toast.
    expect($('Pick-up location is required'), findsWidgets);
    expect($('Drop-off location is required'), findsWidgets);
    expect($('Ride created successfully!'), findsNothing);

    expect($('Sign In'), findsNothing);
  });
}
