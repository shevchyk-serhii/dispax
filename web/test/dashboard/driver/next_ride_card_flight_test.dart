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
}
