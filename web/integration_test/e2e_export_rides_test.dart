import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher opens the ride export screen.
///
/// More → Export → verify the export screen renders its filters and summary,
/// then taps "Copy CSV" (writes to the clipboard, which Patrol can't read back
/// on-device — so we just confirm the action doesn't crash the screen).
/// Exercises GET /rides (all) feeding the export list.
void main() {
  patrolTest('dispatcher opens ride export', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Export').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));

    expect($('Export Rides'), findsWidgets);
    expect($('Copy CSV'), findsWidgets);

    await $('Copy CSV').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // Still on the export screen, still logged in.
    expect($('Export Rides'), findsWidgets);
    expect($('Sign In'), findsNothing);
  });
}
