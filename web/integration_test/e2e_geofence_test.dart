import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher creates a geofence: More → Geofences → FAB → Create Geofence
/// (Name + Latitude + Longitude, Type/Radius keep defaults) → Save.
/// Exercises POST /geofences.
void main() {
  patrolTest('dispatcher creates a geofence', ($) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Geofences').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // Open the Create Geofence dialog. On an empty list this is the
    // "Create Geofence" empty-state button; otherwise the FAB. Both use an add
    // icon and call the same dialog.
    if (find
        .widgetWithText(ElevatedButton, 'Create Geofence')
        .evaluate()
        .isNotEmpty) {
      await $.tester.tap(
        find.widgetWithText(ElevatedButton, 'Create Geofence'),
        warnIfMissed: false,
      );
    } else {
      await $(FloatingActionButton).tap();
    }
    await $.pumpAndSettle();
    expect($('Create Geofence'), findsWidgets);

    // Name / Latitude / Longitude (Munich centre). Type + Radius keep defaults.
    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await $.tester.enterText(dialogFields.at(0), 'E2E Zone');
    await $.tester.enterText(dialogFields.at(1), '48.1374');
    await $.tester.enterText(dialogFields.at(2), '11.5755');
    await $.pumpAndSettle();

    await $.tester.tap(
      find.widgetWithText(ElevatedButton, 'Save'),
      warnIfMissed: false,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    expect($('Create Geofence'), findsNothing);
    expect($('Sign In'), findsNothing);
  });
}
