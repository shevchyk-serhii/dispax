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
  group('DriverPaymentRow', () {
    testWidgets('shows the localized payment label (Cash)', (tester) async {
      final ride = TestFixtures.ride(paymentMethod: 'Cash');
      await pump(tester, DriverPaymentRow(ride: ride, isDark: false));
      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
      // EN label for the 'Cash' wire value.
      expect(find.text('Cash'), findsOneWidget);
    });

    testWidgets('renders nothing when no payment method', (tester) async {
      final ride = TestFixtures.ride();
      await pump(tester, DriverPaymentRow(ride: ride, isDark: false));
      expect(find.byIcon(Icons.payments_outlined), findsNothing);
    });
  });

  group('DriverFlightInfoRow', () {
    testWidgets('shows the full flight info for an airport ride', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightNumber: 'LH1234',
        terminal: 'T2',
        gate: 'G12',
        flightStatus: 'On time',
      );
      await pump(tester, DriverFlightInfoRow(ride: ride, isDark: false));
      // fullFlightInfo embeds the flight number (and gate/terminal/status).
      expect(find.textContaining('LH1234'), findsOneWidget);
    });

    testWidgets('renders nothing for a non-airport ride', (tester) async {
      final ride = TestFixtures.ride(isAirportTransfer: false);
      await pump(tester, DriverFlightInfoRow(ride: ride, isDark: false));
      expect(find.byType(Text), findsNothing);
    });
  });
}
