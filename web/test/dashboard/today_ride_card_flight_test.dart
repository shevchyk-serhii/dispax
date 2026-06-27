// Verifies that the dispatcher/driver "My Rides" card (TodayRideCard) surfaces
// the compact flight line — flight number + gate/terminal + status — when the
// ride is an airport transfer with flight data, and shows nothing flight-related
// for a non-airport ride.
//
// The live gate/terminal/status come from the MUC flight-status service (pushed
// via WebSocket FlightStatusUpdated and persisted on the ride); this test pins
// that the card renders them once they are present on the Ride.
//
// Mutation check: remove the `if (ride.isAirportTransfer && ...)` flight block
// from TodayRideCard -> the "shows the compact flight line" expectation goes red.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/driver_management/widgets/today_ride_card.dart';

import '../helpers/test_fixtures.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets(
    'shows the compact flight line for an airport ride with flight data',
    (tester) async {
      final ride = TestFixtures.airportRide(
        flightNumber: 'LH1234',
        gate: 'G12',
        terminal: 'T2',
        flightStatus: 'Delayed',
      );

      await tester.pumpWidget(wrap(TodayRideCard(ride: ride)));
      await tester.pump();

      // fullFlightInfo => "✈️↓ LH1234 • Gate G12 (Terminal T2) • ⏰ Delayed"
      final flightText = find.textContaining('LH1234');
      expect(flightText, findsOneWidget);
      expect(find.textContaining('Gate G12'), findsOneWidget);
      // "Delayed" appears in both the flight line and the (new) landing line, so assert it
      // specifically on the flight line.
      expect(find.textContaining('LH1234'), findsOneWidget);
      expect(
        find.textContaining('Terminal T2) • ⏰ Delayed'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows no flight line for a non-airport ride', (tester) async {
    final ride = TestFixtures.ride(); // isAirportTransfer defaults to false

    await tester.pumpWidget(wrap(TodayRideCard(ride: ride)));
    await tester.pump();

    expect(find.textContaining('Gate'), findsNothing);
    expect(find.byIcon(Icons.flight), findsNothing);
  });

  testWidgets(
    'shows the recommended terminal-entry time for an arrival with optimalEntryTime',
    (tester) async {
      final ride = TestFixtures.airportRide(
        isArrival: true,
        optimalEntryTime: DateTime(2026, 3, 15, 9, 40),
      );

      await tester.pumpWidget(wrap(TodayRideCard(ride: ride)));
      await tester.pump();

      // Default locale (en): "Entry at 09:40".
      expect(find.textContaining('09:40'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);
    },
  );

  testWidgets(
    'shows no terminal-entry line when optimalEntryTime is absent',
    (tester) async {
      // Arrival airport ride but the backend did not compute an entry time.
      final ride = TestFixtures.airportRide(isArrival: true);

      await tester.pumpWidget(wrap(TodayRideCard(ride: ride)));
      await tester.pump();

      expect(find.byIcon(Icons.login), findsNothing);
    },
  );

  testWidgets(
    'shows no terminal-entry line for a departure even with optimalEntryTime',
    (tester) async {
      // Departure (isArrival=false): the entry-time line is arrival-only.
      final ride = TestFixtures.airportRide(
        isArrival: false,
        optimalEntryTime: DateTime(2026, 3, 15, 9, 40),
      );

      await tester.pumpWidget(wrap(TodayRideCard(ride: ride)));
      await tester.pump();

      expect(find.byIcon(Icons.login), findsNothing);
    },
  );
}
