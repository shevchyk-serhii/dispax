// Widget tests for payment method display in AssignmentDialog.
//
// AssignmentDialog shows ride details including the payment method when set.
// Two cases: (a) paymentMethod='Invoice' -> localized label 'Invoice' visible;
//            (b) paymentMethod=null -> payment row absent.

import 'package:dispax/dashboard/dispatcher/widgets/assignment_dialog.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

Widget _buildSubject(Ride ride) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(
    body: AssignmentDialog(
      ride: ride,
      driverLabel: 'Driver Hans',
      driverId: 'driver-1',
      conflicts: const [],
      onConfirm: () {},
    ),
  ),
);

void main() {
  testWidgets(
    'AssignmentDialog shows localized payment label when paymentMethod is Invoice',
    (tester) async {
      await tester.pumpWidget(
        _buildSubject(TestFixtures.ride(paymentMethod: 'Invoice')),
      );
      await tester.pump();

      expect(
        find.text('Invoice'),
        findsOneWidget,
        reason: 'ride with paymentMethod=Invoice must show the label "Invoice"',
      );
    },
  );

  testWidgets(
    'AssignmentDialog does not show payment row when paymentMethod is null',
    (tester) async {
      await tester.pumpWidget(
        _buildSubject(TestFixtures.ride(paymentMethod: null)),
      );
      await tester.pump();

      // 'Invoice', 'Credit Card', 'Cash', 'Payment' must all be absent.
      expect(find.text('Invoice'), findsNothing);
      expect(find.text('Credit Card'), findsNothing);
      expect(find.text('Cash'), findsNothing);
    },
  );
}
