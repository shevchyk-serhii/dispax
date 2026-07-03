import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Client rates a completed ride from the Rides (history) tab.
///
/// The "Rate this ride" action only shows on a Completed, not-yet-rated ride,
/// so we drive a ride all the way to Completed over HTTP first (client books,
/// dispatcher assigns + starts + completes). Then we log in as the client, open
/// the Rides tab, tap "Rate this ride", tap the 5th star, and confirm.
///
/// The rating is asserted over HTTP via GET /rides/{id}/rating, so the test goes
/// red if the star tap or Confirm is a no-op — a UI-only "dialog closed" check
/// would pass even if nothing persisted.
void main() {
  patrolTest('client rates a completed ride five stars', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    // Bounded pump at boot instead of pumpAndSettle (auth-restore spinner).
    for (var i = 0; i < 5; i++) {
      await $.pump(const Duration(milliseconds: 300));
    }

    final clientToken = await apiLogin(kDevClient1, kDevPassword);
    final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
    // Book → assign → start → complete, all over HTTP.
    final rideId = await completeRide(clientToken, dispatcherToken);
    expect(
      await rideStatus(rideId, dispatcherToken),
      'Completed',
      reason: 'seed ride should be Completed before rating',
    );

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Open the Rides (history) tab where completed rides expose "Rate this ride".
    await tapNav($, 'Rides');
    final rateLink = find.text('Rate this ride');
    expect(
      await pumpUntilVisible($, rateLink),
      isTrue,
      reason: 'a completed unrated ride should offer "Rate this ride"',
    );
    await $.tester.tap(rateLink.first, warnIfMissed: false);
    await pumpFor($);

    // RateRideDialog: five star IconButtons (Icons.star_border when empty). Tap
    // the last one for a 5-star rating, then confirm.
    final stars = find.byWidgetPredicate(
      (w) => w is Icon && (w.icon == Icons.star_border || w.icon == Icons.star),
    );
    expect(
      stars,
      findsWidgets,
      reason: 'the rate dialog should render star icons',
    );
    await $.tester.tap(stars.last, warnIfMissed: false);
    await pumpFor($);
    await $('Confirm').tap();
    await pumpFor($);

    // Backend: the rating was persisted with value 5. The submit goes through a
    // service call, so poll GET /rides/{id}/rating until it lands.
    ApiResult? res;
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      res = await apiGet('/rides/$rideId/rating', clientToken);
      if (res.status == 200) break;
    }
    expect(res!.status, 200, reason: 'a rating should now exist for the ride');
    expect(
      (res.body as Map<String, dynamic>)['rating'],
      5,
      reason: 'the persisted rating should match the 5 stars tapped',
    );
  });
}
