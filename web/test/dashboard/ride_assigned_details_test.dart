import 'package:dispax/dashboard/driver/ride_assigned_details.dart';
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

    testWidgets('shows fallback text when ride is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RideAssignedDetails(ride: null)),
        ),
      );

      expect(
        find.text('You have been assigned a new ride. Do you accept it?'),
        findsOneWidget,
      );
    });
  });
}
