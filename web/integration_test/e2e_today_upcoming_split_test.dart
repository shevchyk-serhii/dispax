import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Regression e2e for the driver Today/Upcoming duplicate-render bug.
///
/// A ride scheduled later *today* used to satisfy both tab filters
/// (getTodayRides: today's window; getUpcomingRides: a bare `isAfter(now)`), so
/// it appeared in BOTH the Today and Upcoming segments. The fix gives the two
/// filters a shared day boundary: today owns the current calendar day, Upcoming
/// starts at tomorrow 00:00. This test seeds an assigned ride for later today on
/// driver1 (Hans) and asserts it shows under Today but NOT under Upcoming.
///
/// Driver1's "My Rides" Today screen has a segmented control: "Today · N",
/// "Upcoming", "History". We read the ride's pickup label (a destination
/// fragment) under each segment.
void main() {
  // A unique destination fragment so we can find exactly this ride's card.
  const marker = 'Olympiapark';

  patrolTest('a ride later today shows in Today, not Upcoming', ($) async {
    await resetTestData();

    // Seed an assigned ride for later today on Hans (driver1). Pick a late hour
    // today but never earlier than now+1h. If the run is already so late that
    // "later today" would cross midnight, there is nothing meaningful to assert.
    final now = DateTime.now();
    final lateToday = DateTime(now.year, now.month, now.day, 22, 0);
    if (!lateToday.isAfter(now.add(const Duration(hours: 1)))) {
      markTestSkipped('Too late in the day to seed a "later today" ride.');
      return;
    }

    final clientToken = await apiLogin(kDevClient1, kDevPassword);
    final dispatcherToken = await apiLogin(kDevDispatcher, kDevPassword);
    // Create a ride with a unique destination so its card is identifiable, then
    // assign it to Hans (driver1) so it lands on his "My Rides" board.
    final marked = await createRide(
      clientToken,
      to: '$marker, München',
      pickupDateTime: lateToday.toUtc().toIso8601String(),
    );
    final markedId = (marked.body as Map<String, dynamic>)['id'] as String;
    await assignDriver(markedId, dispatcherToken, driverId: hansDriverId);

    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Driver lands on the Today ("My Rides") screen by default.
    await $.pump(const Duration(seconds: 2));

    // Today segment: the marked ride is present.
    await $.tester.tap(find.textContaining('Today').first, warnIfMissed: false);
    await $.pump(const Duration(seconds: 1));
    expect(
      find.textContaining(marker),
      findsWidgets,
      reason: 'the later-today ride must appear under Today',
    );

    // Upcoming segment: the same ride must NOT be there.
    await $.tester.tap(
      find.textContaining('Upcoming').first,
      warnIfMissed: false,
    );
    await $.pump(const Duration(seconds: 1));
    expect(
      find.textContaining(marker),
      findsNothing,
      reason: 'a later-today ride must not also appear under Upcoming',
    );
  });
}
