import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Driver rejects an assigned ride with a reason from the Today tab.
///
/// The "Reject" action only appears on a card whose status is Assigned (before
/// the driver confirms), so we seed an Assigned ride for driver1 (Hans Weber)
/// over HTTP first: client books, dispatcher assigns to Hans. Then we log in as
/// the driver, tap "Reject", pick a preset reason, and submit.
///
/// The backend reject flow returns the ride to Requested and clears the driver
/// (see RideService.rejectRide). We assert both over HTTP, so the test goes red
/// if the button is a no-op or if the reject does not fully release the ride
/// back to the pool. (rejectedBy is stored server-side but not exposed in the
/// ride DTO, so we assert the observable status + driver release instead.)
void main() {
  patrolTest('driver rejects an assigned ride with a reason', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    // Don't pumpAndSettle at boot: while auth state is restored the app may show
    // a spinner, so settle can time out. Pump a few bounded frames instead.
    for (var i = 0; i < 5; i++) {
      await $.pump(const Duration(milliseconds: 300));
    }

    final clientToken = await apiLogin(kDevClient1, kDevPassword);
    final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
    final rideId = await createRideId(clientToken);
    final assign = await assignDriver(
      rideId,
      dispatcherToken,
      driverId: hansDriverId,
    );
    expect(assign.status, 200, reason: 'seed assign should succeed');

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // The Reject button sits on the Assigned (not-yet-confirmed) card.
    await $('Reject').waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Reject').scrollTo().tap();
    await pumpFor($);

    // RejectRideDialog: pick the first preset reason chip ("Pickup too far"),
    // then confirm with the dialog's "Reject" button.
    await $('Pickup too far').tap();
    await pumpFor($);
    // The dialog's action button is also labelled "Reject"; tap the last match
    // (the AlertDialog action, not the card button underneath).
    await $.tester.tap(find.text('Reject').last, warnIfMissed: false);
    await pumpFor($);

    // Backend: the ride is released back to Requested and unassigned. The tap
    // dispatches through a BLoC, so poll rather than reading once.
    Map<String, dynamic>? ride;
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      ride = await rideJson(rideId, dispatcherToken);
      if (ride['status'] == 'Requested') break;
    }
    expect(
      ride!['status'],
      'Requested',
      reason: 'reject must return the ride to the pool as Requested',
    );
    expect(
      ride['driverId'],
      isNull,
      reason: 'reject must clear the assigned driver',
    );
  });
}
