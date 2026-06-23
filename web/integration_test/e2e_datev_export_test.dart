import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Dispatcher opens the DATEV export screen.
///
/// More → DATEV → verify the German booking-stack export renders its three
/// sections (Erlöse / Ausgaben / Zusammenfassung). The CSV copy/download go to
/// the clipboard / filesystem, which Patrol can't assert on-device, so this is
/// a smoke test that the export screen builds against the backend
/// (GET /export/datev). DATEV CSV formatting is covered by backend specs.
void main() {
  patrolTest('dispatcher opens the DATEV export screen', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'More');
    await $('DATEV').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));

    expect($('DATEV Export'), findsWidgets);
    expect($('Erlöse'), findsWidgets);
    expect($('Ausgaben'), findsWidgets);

    expect($('Sign In'), findsNothing);
  });
}
