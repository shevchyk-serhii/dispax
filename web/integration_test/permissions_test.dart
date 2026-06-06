import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_test_app.dart';
import 'test_accounts.dart';

/// E2E test demonstrating Patrol's native automation: it handles the OS-level
/// location permission dialog that the driver flow (geolocator) triggers.
///
/// This is the capability `integration_test` alone cannot provide. Requires the
/// backend on :8080 and `--dart-define=API_BASE_URL=...`.
void main() {
  patrolTest('grants native location permission for the driver flow', (
    $,
  ) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    // Log in as a driver — the driver dashboard requests location access.
    await $(TextFormField).at(0).enterText(kDriverEmail);
    await $(TextFormField).at(1).enterText(kPassword);
    await $('Sign In').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    // If the OS shows a location permission dialog, grant "while in use".
    if (await $.platformAutomator.mobile.isPermissionDialogVisible(
      timeout: const Duration(seconds: 10),
    )) {
      await $.platformAutomator.mobile.grantPermissionWhenInUse();
    }

    // App stays alive after handling the native dialog.
    await $.pumpAndSettle();
    expect($('Welcome Back'), findsNothing);
  });
}
