import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Regression e2e for the stale-estimate bug on the client Book form.
///
/// Estimates are fetched per vehicle class once both From and To are set and are
/// rendered as an "Estimated total" price. Before the fix, clearing an address
/// did not drop the estimate, so the old price stayed on screen for a route that
/// no longer existed. This test enters a full route, waits for the price, clears
/// To, and asserts the price disappears.
///
/// The estimate fetch needs a reachable estimate/geocoding backend; on an
/// emulator without a Mapbox token it can legitimately never produce a price.
/// In that case there is nothing to assert, so the test skips rather than
/// flaking.
void main() {
  patrolTest('clearing the To address drops the price estimate', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Book');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect($('From'), findsWidgets, reason: 'Book form opened');

    // Enter a full route and let the per-class estimates resolve.
    await $(TextFormField).at(0).enterText('Marienplatz, München');
    await $(TextFormField).at(1).enterText('Flughafen München');
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));

    // Wait (bounded) for the "Estimated total" price to appear.
    final priceShown = await _waitForText(
      $,
      'Estimated total',
      timeout: const Duration(seconds: 12),
    );
    if (!priceShown) {
      markTestSkipped(
        'No estimate produced (estimate/geocoding backend unavailable on this '
        'environment) — nothing to assert for the stale-estimate clear.',
      );
      return;
    }

    // Clear the To field — the stale price must be dropped.
    await $(TextFormField).at(1).enterText('');
    await $.pumpAndSettle(timeout: const Duration(seconds: 8));

    expect(
      find.text('Estimated total'),
      findsNothing,
      reason: 'the price must disappear once the route is incomplete',
    );
  });
}

/// Pumps in fixed steps until [text] is visible or [timeout] elapses. Returns
/// whether the text appeared. Avoids pumpAndSettle so it tolerates the live map
/// and animations that never settle.
Future<bool> _waitForText(
  PatrolIntegrationTester $,
  String text, {
  required Duration timeout,
}) async {
  const step = Duration(milliseconds: 400);
  var elapsed = Duration.zero;
  while (elapsed < timeout) {
    if (find.text(text).evaluate().isNotEmpty) return true;
    await $.pump(step);
    elapsed += step;
  }
  return false;
}
