import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_fixtures.dart';

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('NextRideCard flight info', () {
    // The compact "next scheduled ride" card used to omit flight info entirely,
    // so a later airport ride of the day showed no flight number / gate /
    // terminal even though the backend sent it. It must surface the flight now.
    testWidgets('shows the flight number for an airport ride', (tester) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightNumber: 'LH1671',
        terminal: 'T2',
        gate: 'G18',
        flightStatus: 'On time',
      );

      await pump(tester, NextRideCard(ride: ride));

      expect(find.textContaining('LH1671'), findsOneWidget);
    });

    testWidgets('renders no flight row for a non-airport ride', (tester) async {
      final ride = TestFixtures.ride(isAirportTransfer: false);

      await pump(tester, NextRideCard(ride: ride));

      expect(find.byType(DriverFlightInfoRow), findsOneWidget);
      // The row is present but self-hides (empty) for non-airport rides.
      expect(find.textContaining('Gate'), findsNothing);
    });
  });

  group('NextRideCard terminal-entry time', () {
    // The compact card showed the flight but not the recommended terminal-entry
    // time ("Einfahrt um HH:mm") for an arrival — it must surface it now.
    testWidgets('shows the entry time for an airport arrival', (tester) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightNumber: 'LH1671',
        optimalEntryTime: DateTime(2026, 6, 27, 17, 5),
      );

      await pump(tester, NextRideCard(ride: ride));

      // en default locale → "Entry at 17:05".
      expect(find.textContaining('17:05'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);
    });

    testWidgets('shows no entry time for a departure', (tester) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: false,
        flightNumber: 'LH1671',
        optimalEntryTime: DateTime(2026, 6, 27, 17, 5),
      );

      await pump(tester, NextRideCard(ride: ride));

      expect(find.byIcon(Icons.login), findsNothing);
    });
  });

  group('DriverEntryTimeRow', () {
    testWidgets('renders the entry time for an arrival with one', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        optimalEntryTime: DateTime(2026, 6, 27, 9, 40),
      );

      await pump(tester, DriverEntryTimeRow(ride: ride, isDark: false));

      expect(find.textContaining('09:40'), findsOneWidget);
    });

    testWidgets('self-hides when no entry time is present', (tester) async {
      final ride = TestFixtures.ride(isAirportTransfer: true, isArrival: true);

      await pump(tester, DriverEntryTimeRow(ride: ride, isDark: false));

      expect(find.byIcon(Icons.login), findsNothing);
    });
  });
}
