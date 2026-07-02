import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Driver confirms an assigned ride from the Today tab.
///
/// The "Confirm" action only appears on a card whose status is Assigned, so we
/// seed an Assigned ride for driver1 (Hans Weber) over HTTP first: client books,
/// dispatcher assigns to Hans. Then we log in as the driver, tap "Confirm", and
/// assert the backend ride records confirmed=true (queried over HTTP), so the
/// test goes red if the button is a no-op.
void main() {
  patrolTest('driver confirms an assigned ride', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    // Don't pumpAndSettle at boot: while auth state is restored the app may show
    // a spinner (CircularProgressIndicator), so settle can time out. Pump a few
    // bounded frames instead; loginViaUi then waits for the LoginScreen itself.
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

    await $('Confirm').waitUntilVisible(timeout: const Duration(seconds: 20));
    await $('Confirm').scrollTo().tap();
    // Don't pumpAndSettle: the driver Today dashboard runs a perpetual pulse
    // animation, so settle never completes (it times out). Pump a few bounded
    // frames so the tap's request is dispatched, then verify over HTTP.
    for (var i = 0; i < 5; i++) {
      await $.pump(const Duration(milliseconds: 300));
    }

    var confirmed = false;
    for (var i = 0; i < 10 && !confirmed; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final ride = await rideJson(rideId, dispatcherToken);
      confirmed = ride['confirmed'] == true;
    }
    expect(
      confirmed,
      isTrue,
      reason: 'Confirm should set the ride confirmed=true on the backend',
    );
    expect($('Sign in'), findsNothing);
  });
}
