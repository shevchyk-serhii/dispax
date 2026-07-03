import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Dispatcher closes (cancels) a Requested ride straight from the pending-row
/// "Close" button — a different entry point than the client's own "Cancel" on
/// the Home tab (covered by e2e_cancel_ride_test.dart). "Close" opens the same
/// CancelRideDialog but with `role: PersonRole.dispatcher`, which offers a
/// wider staff reason list and a cancellation-fee field the client's dialog
/// does not show.
///
/// Asserts the ride actually reaches Cancelled on the backend — the button's
/// own confirm copy warns "This will cancel the unassigned ride. The client
/// will be notified.", so a wiring regression here would silently leave a
/// ride Requested while the dispatcher believes it was closed.
void main() {
  patrolTest('dispatcher closes a pending ride from the Home list', ($) async {
    await resetTestData();
    final clientToken = await apiLogin(kDevClient1, kDevPassword);
    final rideId = await createRideId(clientToken);

    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Home');
    if ($('Pending').exists) {
      await $('Pending').tap();
      // The dashboard behind this screen runs a perpetual animation, so
      // pumpAndSettle never settles here — use bounded pumps instead,
      // matching patrol_helpers.dart's tapNav pattern.
      await $.pump(const Duration(milliseconds: 300));
      await $.pump(const Duration(milliseconds: 300));
    }

    await $('Close').waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Close').scrollTo().tap();
    await $.pump(const Duration(milliseconds: 300));

    // Staff dialog: pick a reason only available to staff, not clients. The
    // dashboard behind this dialog runs a perpetual animation (as elsewhere
    // on this screen), so pumpAndSettle never settles — bounded pumps instead.
    expect($('Please select a reason for cancellation:'), findsWidgets);
    await $(DropdownButtonFormField<String>).tap();
    await $.pump(const Duration(milliseconds: 300));
    await $('Client No-Show').tap();
    await $.pump(const Duration(milliseconds: 300));

    // Confirm — the button label is "Cancel Ride" (dialog title reused).
    await $.tester.tap(
      find.widgetWithText(ElevatedButton, 'Cancel Ride'),
      warnIfMissed: false,
    );
    await $.pump(const Duration(seconds: 1));
    await $.pump(const Duration(seconds: 1));

    expect($('Please select a reason for cancellation:'), findsNothing);

    // Backend-level assertion: the ride is Cancelled, not left Requested.
    final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
    final status = await rideStatus(rideId, dispatcherToken);
    expect(
      status,
      equals('Cancelled'),
      reason: 'closing from the dispatcher pending row should cancel the ride',
    );
  });
}
