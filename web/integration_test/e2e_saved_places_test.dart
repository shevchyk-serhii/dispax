import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Covers the client "Saved places" flow on the Home tab.
///
/// A client opens Home, taps the empty "Office" saved-place tile (which shows
/// "Add address"), enters an address in the picker sheet, taps "Confirm", and
/// the tile re-renders with the saved address persisted to the backend.
///
/// We use the "Office" slot because the seeded BMW client (client1) only has
/// "Zuhause" + "Flughafen München" addresses — `findByLabel('Office')` matches
/// on the exact label (aliases are ignored), so the Office slot starts empty.
///
/// `POST /api/dev/reset` does NOT truncate `client_addresses` (it is reference
/// data), so to keep this suite repeatable we first delete any Office address a
/// previous run created, via the real API, before driving the UI.
///
/// Geocoding is best-effort and optional (MapboxService.geocodeAddress returns
/// null when the token is unset or the network is unreachable), so the flow is
/// reliable on a CI emulator: the place is created with null coordinates and
/// the tile still updates from the SavedPlacesBloc.
void main() {
  const officeAddress = 'Leopoldstraße 1, München';

  patrolTest('client adds a saved place (Office) from the Home tab', ($) async {
    await resetTestData();
    // Pre-clean: remove any "Office" address left by a previous run so the slot
    // starts empty (dev/reset does not wipe client_addresses).
    await _deleteOfficeAddresses();

    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Land on the Home tab and find the saved-places section.
    await tapNav($, 'Home');
    await $(
      'SAVED PLACES',
    ).waitUntilVisible(timeout: const Duration(seconds: 12));

    // The empty "Office" slot renders its placeholder and is tappable.
    expect(
      $('Office'),
      findsWidgets,
      reason: 'Office saved-place slot renders',
    );
    expect(
      find.text('Add address'),
      findsWidgets,
      reason: 'the Office slot starts empty after the pre-clean',
    );
    await $.tester.tap(find.text('Office').first, warnIfMissed: false);
    await $.pumpAndSettle(timeout: const Duration(seconds: 12));

    // Address picker sheet: type an address and Confirm.
    final field = find.byType(TextField);
    expect(field, findsWidgets, reason: 'address picker opened');
    await $.tester.enterText(field.first, officeAddress);
    await $.pumpAndSettle();
    await $('Confirm').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    // The saved place is persisted and the Office tile now shows the address
    // (the SavedPlacesBloc reloads after the save and the tile rebuilds).
    await $(
      officeAddress,
    ).waitUntilVisible(timeout: const Duration(seconds: 15));
    expect($(officeAddress), findsWidgets);
    expect($('Sign In'), findsNothing);
  });
}

/// Deletes every "Office"-labelled saved address for the BMW client via the
/// real API, so the test's slot starts empty and the run is repeatable.
/// Best-effort: a missing/unreachable backend is swallowed (the test's own
/// skipIfBackendDown handles that path).
Future<void> _deleteOfficeAddresses() async {
  try {
    final token = await apiLogin(kDevClient1, kDevPassword);
    final res = await apiGet('/clients/$bmwClientId/addresses', token);
    final body = res.body;
    if (body is! List) return;
    for (final entry in body) {
      if (entry is Map &&
          (entry['label'] as String?)?.toLowerCase() == 'office') {
        final id = entry['id'] as String?;
        if (id != null) {
          await http.delete(
            Uri.parse('$kApiBaseUrl/clients/$bmwClientId/addresses/$id'),
            headers: {'Authorization': 'Bearer $token'},
          );
        }
      }
    }
  } catch (_) {
    // Ignore — backend unreachable is handled by skipIfBackendDown later.
  }
}
