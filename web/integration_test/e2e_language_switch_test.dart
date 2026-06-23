import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Exercises the in-app language switcher on the Settings screen.
///
/// A client logs in, opens Settings, taps the Language row, picks "Deutsch"
/// from the bottom-sheet picker, and the UI re-renders in German live (no
/// restart). We then switch back to English so the shared backend account's
/// `preferredLanguage` is left as it started for other suites.
///
/// Assertions key off localized labels that are visible on the Settings screen
/// itself: General → "Allgemein", Language → "Sprache", Appearance →
/// "Darstellung". The bottom-nav "Settings" tab label is hard-coded (not
/// localized), so we drive navigation by that constant and assert on the
/// localized card content instead.
void main() {
  patrolTest('client switches language to German and back via Settings', (
    $,
  ) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Open the Settings tab (hard-coded label) and confirm we start in English.
    await tapNav($, 'Settings');
    await $('Language').waitUntilVisible(timeout: const Duration(seconds: 10));
    expect($('General'), findsWidgets, reason: 'should start in English');

    // Open the language picker and choose German.
    await $('Language').scrollTo().tap();
    await $.pumpAndSettle();
    await $('Deutsch').waitUntilVisible(timeout: const Duration(seconds: 10));
    await $('Deutsch').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // UI re-rendered in German: the localized Settings card labels switch.
    await $('Sprache').waitUntilVisible(timeout: const Duration(seconds: 10));
    expect($('Allgemein'), findsWidgets, reason: 'General → Allgemein');
    expect($('Darstellung'), findsWidgets, reason: 'Appearance → Darstellung');
    // The English label must be gone now.
    expect($('General'), findsNothing);

    // Switch back to English so the shared account's preferredLanguage is
    // restored for downstream suites that assert on English text.
    await $('Sprache').scrollTo().tap();
    await $.pumpAndSettle();
    await $('English').waitUntilVisible(timeout: const Duration(seconds: 10));
    await $('English').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await $('Language').waitUntilVisible(timeout: const Duration(seconds: 10));
    expect($('General'), findsWidgets, reason: 'restored to English');
    expect($('Sign In'), findsNothing);
  });
}
