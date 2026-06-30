// Widget tests for the manual flight-refresh button on the driver/dispatcher list card's
// flight line (DriverFlightInfoRow). The button shows only when onRefresh is wired and the
// ride has a flight number; it spins and disables while refreshing.

import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('de'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('DriverFlightInfoRow refresh button', () {
    final airportRide = TestFixtures.ride(
      isAirportTransfer: true,
      isArrival: true,
      flightNumber: 'LH1668',
      gate: 'G12',
      terminal: '2',
      flightStatus: 'unknown',
    );

    testWidgets('is hidden when no onRefresh is provided', (tester) async {
      await _pump(
        tester,
        DriverFlightInfoRow(ride: airportRide, isDark: false),
      );
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('shows and fires onRefresh when tapped', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        DriverFlightInfoRow(
          ride: airportRide,
          isDark: false,
          onRefresh: () => taps++,
        ),
      );
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('shows a spinner and disables while refreshing', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        DriverFlightInfoRow(
          ride: airportRide,
          isDark: false,
          isRefreshing: true,
          onRefresh: () => taps++,
        ),
      );
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Tap the refresh button specifically (the one holding the spinner) — the radar
      // button is a separate IconButton, so byType(IconButton) is ambiguous now.
      final refreshButton = find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(IconButton),
      );
      await tester.tap(refreshButton);
      await tester.pump();
      expect(taps, 0); // disabled → no callback
    });

    testWidgets('is hidden for a non-airport ride even with onRefresh', (
      tester,
    ) async {
      final plain = TestFixtures.ride(isAirportTransfer: false);
      await _pump(
        tester,
        DriverFlightInfoRow(ride: plain, isDark: false, onRefresh: () {}),
      );
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    // The Flightradar (radar) and refresh actions must line up: same 32×32 box and
    // the same vertical center. Mutation: give either button a different size/footprint
    // (e.g. drop the radar's SizedBox(32) wrapper) → centers/heights diverge → red.
    testWidgets('flightradar and refresh actions are equal-sized and aligned', (
      tester,
    ) async {
      await _pump(
        tester,
        DriverFlightInfoRow(ride: airportRide, isDark: false, onRefresh: () {}),
      );

      final radar = tester.getRect(find.byIcon(Icons.radar));
      final refresh = tester.getRect(find.byIcon(Icons.refresh));
      // Both flight-action icons share the same vertical center (aligned with each other).
      expect((radar.center.dy - refresh.center.dy).abs(), lessThan(0.5));

      // Both actions render inside an equal-sized 32×32 IconButton footprint.
      final radarBox = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.radar),
          matching: find.byType(IconButton),
        ),
      );
      final refreshBox = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.refresh),
          matching: find.byType(IconButton),
        ),
      );
      expect(radarBox, refreshBox);
    });
  });
}
