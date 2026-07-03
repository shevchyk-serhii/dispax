import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Dispatcher reassigns a pending ride to another client via the ride-details
/// "Edit" dialog (ClientAutocompleteField) and the change SURVIVES a refetch.
///
/// Regression guard for the client_id persistence bug: the ride UPDATE's SET
/// clause omitted client_id, so the PUT response (built from the in-memory
/// object) showed the new client while the database kept the old one — the
/// dialog looked successful, but returning to the pending list brought the old
/// client back. The UI flow alone cannot catch that (the optimistic response
/// paints the new name), so this test asserts the backend state via HTTP after
/// the save, exactly like the other e2e_* suites.
void main() {
  patrolTest('dispatcher reassigns a pending ride to another client', (
    $,
  ) async {
    await resetTestData();
    final clientToken = await apiLogin(kDevClient1, kDevPassword);
    final rideId = await createRideId(clientToken);

    await bootstrapTestApp();
    // No pumpAndSettle after boot: the login/dashboard screens run repeating
    // animations, so settle can hang for its full 10-minute timeout and the
    // instrumentation dies without ever reporting a verdict. Bounded pumps
    // instead (same rationale as patrol_helpers.dart).
    await pumpFor($, const Duration(seconds: 2));

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

    // Open the ride's details screen via the info icon (its "Details" label is
    // a tooltip only — see e2e_duplicate_ride_test.dart).
    await $(
      'Flughafen München',
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    await $.tester.tap(
      find.byIcon(Icons.info_outline).first,
      warnIfMissed: false,
    );
    // The details screen opens via a Hero transition — pump through it in
    // bounded steps rather than pumpAndSettle (which never settles here).
    for (var i = 0; i < 5; i++) {
      await $.pump(const Duration(milliseconds: 300));
    }

    // Open the edit dialog. Like "Duplicate", the button needs scrollTo() to
    // become hit-testable.
    await $('Edit').scrollTo().tap();
    await pumpFor($, const Duration(seconds: 1));
    expect($('Edit Ride'), findsWidgets);

    // The client field is the dialog's autocomplete (label 'Client Name'),
    // pre-filled with the current client. Typing replaces the text and opens
    // the options overlay; tap the other seeded client in it.
    final clientField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await $.tester.enterText(clientField.first, 'Siemens');
    await pumpFor($, const Duration(seconds: 1));
    await $('Siemens - Frau Meier').tap();
    await pumpFor($, const Duration(seconds: 1));

    await $('Save').tap();
    // Bounded pumps while the PUT round-trips and the dialog pops.
    await pumpFor($, const Duration(seconds: 3));

    // Backend-level assertion — the reassignment must be PERSISTED, not just
    // painted from the PUT response. A fresh GET is what exposed the lost
    // client_id bug.
    final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
    final rideAfter = await rideJson(rideId, dispatcherToken);
    expect(
      rideAfter['clientId'],
      equals(siemensClientId),
      reason: 'the client reassignment must survive a refetch from the DB',
    );
    expect(rideAfter['clientName'], equals('Siemens - Frau Meier'));

    // UI-level assertion: the details screen now shows the new client.
    expect($('Siemens - Frau Meier'), findsWidgets);
  });
}
