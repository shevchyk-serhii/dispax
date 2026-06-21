import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// NEGATIVE: the Create Template dialog rejects an empty form.
///
/// More → Templates → add → submit with everything blank. Each required field
/// (Template Name / Client / From / To / Pickup Time) shows its "Required"
/// validator message and the dialog stays open (no template created).
void main() {
  patrolTest('create template rejects an empty form', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('Templates').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await $.tester.tap(find.byIcon(Icons.add).first, warnIfMissed: false);
    await $.pumpAndSettle();
    expect($('Create Template'), findsWidgets);

    // Submit immediately with all fields blank.
    await $.tester.tap(
      find.widgetWithText(ElevatedButton, 'Create'),
      warnIfMissed: false,
    );
    await $.pumpAndSettle();

    // The form validators fire ("Required") and the dialog remains open.
    expect($('Required'), findsWidgets);
    expect($('Create Template'), findsWidgets);

    expect($('Sign In'), findsNothing);
  });
}
