import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Dispatcher hands off a Requested ride to an external partner company +
/// driver via the pending-row "Hand off" button → HandOffRideDialog. Neither
/// company nor driver exist yet in a fresh test DB, so the dialog's inline
/// "Add new company" / "Add new driver" sub-forms must be exercised too — the
/// multi-step wiring the dialog's own doc comments flag as regression-prone
/// (ProviderNotFoundException risk from the overlay context).
///
/// Asserts both the UI feedback and the backend's terminal state: the ride
/// ends up `HandedOff`, not silently left `Requested`.
void main() {
  patrolTest('dispatcher hands off a ride to an external partner', ($) async {
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
      await $.pump(const Duration(milliseconds: 300));
      await $.pump(const Duration(milliseconds: 300));
    }

    await $(
      'Hand Off',
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Hand Off').scrollTo().tap();
    await $.pump(const Duration(milliseconds: 300));

    expect($('Hand Off Ride'), findsWidgets);

    // The dialog shows a CircularProgressIndicator until the partner-company
    // and external-driver directories load — pumpAndSettle can't settle while
    // it spins, so wait for the real content (the "+ Add new company" link).
    await $(
      '+ Add new company',
    ).waitUntilVisible(timeout: const Duration(seconds: 15));

    // Company dropdown is empty on a fresh DB — add one inline. The dashboard
    // behind the dialog keeps a perpetual animation running (as elsewhere in
    // this screen), so pumpAndSettle never settles here either — use bounded
    // pumps instead, matching patrol_helpers.dart's tapNav pattern. Scope the
    // TextField finder to the dialog: an unscoped index 0 matches the pending
    // panel's "Search client, address..." field sitting behind the dialog.
    final dialogTextFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await $('+ Add new company').tap();
    await $.pump(const Duration(milliseconds: 300));
    await $.tester.enterText(dialogTextFields.first, 'Alpine Transfers GmbH');
    await $('Add').tap();
    await $.pump(const Duration(milliseconds: 300));
    await $.pump(const Duration(milliseconds: 300));

    // Driver dropdown is empty too — add one inline.
    await $('+ Add new driver').tap();
    await $.pump(const Duration(milliseconds: 300));
    await $.tester.enterText(dialogTextFields.first, 'Otto Bauer');
    await $('Add').last.tap();
    await $.pump(const Duration(milliseconds: 300));
    await $.pump(const Duration(milliseconds: 300));

    // Confirm the hand-off (button label is also "Hand Off").
    await $('Hand Off').last.tap();
    await $.pump(const Duration(seconds: 1));
    await $.pump(const Duration(seconds: 1));

    // Backend-level assertion: the ride is now HandedOff, not Requested.
    final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
    final status = await rideStatus(rideId, dispatcherToken);
    expect(
      status,
      equals('HandedOff'),
      reason: 'ride should transition to HandedOff after a successful hand-off',
    );
  });
}
