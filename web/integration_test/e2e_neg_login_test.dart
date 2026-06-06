import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:oktopus/auth/login_screen.dart';

import 'patrol_helpers.dart';

/// Negative: logging in with a wrong password must keep the user on the login
/// screen and surface an error — it must not authenticate.
void main() {
  patrolTest('wrong password is rejected and stays on login', ($) async {
    await bootstrapTestApp();
    await $.pumpAndSettle();

    expect($(LoginScreen), findsOneWidget);

    await $(TextFormField).at(0).enterText(kDevClient1);
    await $(TextFormField).at(1).enterText('definitely-wrong-password');
    await $('Sign In').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    // If the backend is unreachable the test is meaningless — skip it.
    if (!$(LoginScreen).exists) {
      // Unexpectedly authenticated → that's a real failure.
      fail('Login succeeded with a wrong password');
    }

    // Still on the login screen, with the error surfaced.
    expect($(LoginScreen), findsOneWidget);
    expect($('Invalid email or password'), findsWidgets);
  });
}
