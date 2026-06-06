import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Client creates an airport-transfer ride: fill From/To, enable the "Airport
/// Transfer" switch, choose Departure, enter a flight number, then submit.
/// Exercises POST /rides with isAirportTransfer=true.
void main() {
  patrolTest('client creates an airport-transfer ride', ($) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevClient1, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Book');
    await $(TextFormField).at(0).enterText('Maximilianstraße 10, München');
    await $(TextFormField).at(1).enterText('Flughafen München Terminal 2');
    await $.pumpAndSettle();

    // Dismiss the soft keyboard (it otherwise covers the Airport Transfer
    // switch lower in the form) by unfocusing the text fields.
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();

    // Enable the Airport Transfer switch via its unique subtitle text (inside
    // the tappable SwitchListTile). scrollTo brings it above the fold.
    await $('Enable if this is an airport pickup/drop-off').scrollTo().tap();
    await $.pumpAndSettle();
    await $('Departure').waitUntilVisible(timeout: const Duration(seconds: 8));

    // Choose Departure and enter the flight number. The flight field is the
    // TextFormField whose decoration labelText is 'Flight Number'.
    await $('Departure').tap();
    await $.pumpAndSettle();
    // The flight field is the 3rd TextFormField (From, To, Flight Number).
    // Use Patrol's enterText so onChanged fires and updates the form bloc.
    await $(TextFormField).at(2).scrollTo();
    await $(TextFormField).at(2).enterText('LH123');
    await $.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();

    await $('Create Ride').scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    expect($('Sign In'), findsNothing);
  });
}
