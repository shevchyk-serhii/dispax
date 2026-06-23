import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher opens the Notification Center.
///
/// More → Notifications → verify the inbox renders, exercise the category
/// filter chips, and switch to the Settings (preferences) tab. Exercises
/// GET /notifications and GET /notifications/unread-count.
void main() {
  patrolTest('dispatcher browses the notification center', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Notifications').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));
    expect($('Notifications'), findsWidgets);

    // Filter chips at the top of the inbox.
    if ($('Rides').exists) {
      await $('Rides').tap();
      await $.pumpAndSettle();
    }

    // Switch to the preferences tab (second tab in the TabBar).
    if ($('Settings').exists) {
      await $('Settings').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    }

    expect($('Sign In'), findsNothing);
  });
}
