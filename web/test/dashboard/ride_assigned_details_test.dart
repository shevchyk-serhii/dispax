import 'package:dispax/dashboard/driver/ride_assigned_details.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('RideAssignedDetails', () {
    testWidgets(
      'renders client, pickup, destination and price when ride is provided',
      (tester) async {
        final ride = TestFixtures.ride(
          clientName: 'Acme GmbH',
          price: 42.5,
          from: TestFixtures.location(address: 'Marienplatz 1'),
          to: TestFixtures.location(address: 'Airport T2'),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: RideAssignedDetails(ride: ride)),
          ),
        );

        expect(find.text('Acme GmbH'), findsOneWidget);
        expect(find.text('Marienplatz 1'), findsOneWidget);
        expect(find.text('Airport T2'), findsOneWidget);
        expect(find.text('€42.50'), findsOneWidget);
      },
    );

    testWidgets('omits price row when ride.price is null', (tester) async {
      final ride = TestFixtures.ride(
        price: null,
        from: TestFixtures.location(address: 'Marienplatz 1'),
        to: TestFixtures.location(address: 'Airport T2'),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RideAssignedDetails(ride: ride)),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('€') ?? false),
        ),
        findsNothing,
      );
    });

    testWidgets('shows the localized payment method label when present', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        paymentMethod: 'Card',
        from: TestFixtures.location(address: 'Marienplatz 1'),
        to: TestFixtures.location(address: 'Airport T2'),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RideAssignedDetails(ride: ride)),
        ),
      );

      expect(find.text('Credit Card'), findsOneWidget);
    });

    testWidgets('omits payment row when ride.paymentMethod is null', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        from: TestFixtures.location(address: 'Marienplatz 1'),
        to: TestFixtures.location(address: 'Airport T2'),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RideAssignedDetails(ride: ride)),
        ),
      );

      for (final label in ['Invoice', 'Cash', 'Credit Card', 'Payment']) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('shows fallback text when ride is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: RideAssignedDetails(ride: null)),
        ),
      );

      expect(
        find.text('You have been assigned a new ride. Do you accept it?'),
        findsOneWidget,
      );
    });
  });
}
