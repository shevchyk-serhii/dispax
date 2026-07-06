// Widget tests for RideFlightCard — the flight-details card on the ride details screen.
// Runs under the German locale to lock in that every label is localized (no hardcoded
// English leaking through) and that the status renders via localizedFlightStatus
// (so a raw "unknown" wire value shows the neutral "Unbekannt", not "unknown").

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/ride_management/widgets/ride_flight_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('de'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('RideFlightCard (German locale)', () {
    testWidgets('localizes every label — no hardcoded English', (tester) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightNumber: 'DE1811',
        flightTime: DateTime(2026, 6, 29, 23, 5),
        terminal: 'T1D',
        flightStatus: 'en_route',
      );
      await _pump(tester, RideFlightCard(ride: ride));

      // Header + field labels are German now.
      expect(find.text('Fluginformationen'), findsOneWidget);
      expect(find.text('Flugnummer'), findsOneWidget);
      expect(find.text('Ankunftszeit'), findsOneWidget);
      expect(find.text('Terminal'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      // The old hardcoded English must be gone.
      expect(find.text('Flight Information'), findsNothing);
      expect(find.text('Flight Number'), findsNothing);
      expect(find.text('Arrival Time'), findsNothing);
    });

    testWidgets(
      'renders a raw "unknown" status as the neutral localized label',
      (tester) async {
        final ride = TestFixtures.ride(
          isAirportTransfer: true,
          isArrival: true,
          flightNumber: 'DE1811',
          flightTime: DateTime(2026, 6, 29, 23, 5),
          flightStatus: 'unknown',
        );
        await _pump(tester, RideFlightCard(ride: ride));

        // The raw wire value never reaches the UI; the German label does.
        expect(find.text('unknown'), findsNothing);
        expect(find.text('Unbekannt'), findsOneWidget);
      },
    );

    testWidgets('uses "Abflugzeit" for a departure flight', (tester) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: false,
        flightNumber: 'LH123',
        flightTime: DateTime(2026, 6, 29, 8, 30),
        flightStatus: 'scheduled',
      );
      await _pump(tester, RideFlightCard(ride: ride));

      expect(find.text('Abflugzeit'), findsOneWidget);
      expect(find.text('Ankunftszeit'), findsNothing);
    });
  });

  group('RideFlightCard refresh button', () {
    Ride airportRide() => TestFixtures.ride(
      isAirportTransfer: true,
      isArrival: true,
      flightNumber: 'DE1811',
      flightTime: DateTime(2026, 6, 29, 23, 5),
      flightStatus: 'unknown',
    );

    testWidgets('is hidden when no onRefresh is provided', (tester) async {
      await _pump(tester, RideFlightCard(ride: airportRide()));
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('shows the button and fires onRefresh when tapped', (
      tester,
    ) async {
      var tapped = 0;
      await _pump(
        tester,
        RideFlightCard(ride: airportRide(), onRefresh: () => tapped++),
      );
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('shows a spinner and disables the button while refreshing', (
      tester,
    ) async {
      var tapped = 0;
      await _pump(
        tester,
        RideFlightCard(
          ride: airportRide(),
          isRefreshing: true,
          onRefresh: () => tapped++,
        ),
      );
      // Refresh icon is replaced by a spinner, and the button is disabled.
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Target the refresh button specifically (the one wrapping the spinner) —
      // the card now also renders copy IconButtons next to the flight fields.
      final refreshButton = find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(IconButton),
      );
      expect(refreshButton, findsOneWidget);
      await tester.tap(refreshButton);
      await tester.pump();
      expect(tapped, 0); // disabled → no callback
    });
  });
}
