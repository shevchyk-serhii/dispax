import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

/// Pumps [DriverRideActionsRow] for a ride in [status] inside a narrow,
/// width-constrained card so the regression (Reject overflowing the right edge
/// of the card on small screens) would surface as a RenderFlex overflow.
Future<void> pumpActionsRow(
  WidgetTester tester, {
  required RideStatus status,
  double width = 360,
  VoidCallback? onShareRide,
}) async {
  final ride = TestFixtures.ride(driverId: 'driver-1', status: status);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            // A card narrower than the phone in the report still has to fit.
            width: width,
            child: DriverRideActionsRow(
              ride: ride,
              isDark: false,
              onNavigate: () {},
              onShareRide: onShareRide,
              onCallClient: () {},
              onConfirmRide: () {},
              onRejectRide: () {},
              onStartRide: () {},
              onCompleteRide: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DriverRideActionsRow', () {
    testWidgets(
      'assigned: shows Confirm and Reject without overflowing a narrow card',
      (tester) async {
        await pumpActionsRow(tester, status: RideStatus.assigned, width: 320);

        // Both primary actions are present and fully laid out.
        expect(find.text('Confirm'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);

        // No RenderFlex overflow was recorded while building the row.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('assigned: Confirm and Reject share equal width', (
      tester,
    ) async {
      await pumpActionsRow(tester, status: RideStatus.assigned, width: 360);

      final confirmWidth = tester
          .getSize(
            find.ancestor(
              of: find.text('Confirm'),
              matching: find.byType(FilledButton),
            ),
          )
          .width;
      final rejectWidth = tester
          .getSize(
            find.ancestor(
              of: find.text('Reject'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .width;

      // Equal Expanded shares => identical widths (within sub-pixel rounding).
      expect((confirmWidth - rejectWidth).abs(), lessThan(1.0));
    });

    testWidgets('confirmed: Start button fits a narrow card', (tester) async {
      await pumpActionsRow(tester, status: RideStatus.confirmed, width: 320);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inProgress: Complete button fits a narrow card', (
      tester,
    ) async {
      await pumpActionsRow(tester, status: RideStatus.inProgress, width: 320);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a Share button when onShareRide is provided', (
      tester,
    ) async {
      var shared = false;
      await pumpActionsRow(
        tester,
        status: RideStatus.confirmed,
        onShareRide: () => shared = true,
      );

      // The share icon is the only entry point to the guest tracking link from
      // the driver's live ride card.
      final shareButton = find.byIcon(Icons.ios_share_rounded);
      expect(shareButton, findsOneWidget);

      await tester.tap(shareButton);
      await tester.pump();
      expect(shared, isTrue);
    });

    testWidgets('hides the Share button when onShareRide is null', (
      tester,
    ) async {
      await pumpActionsRow(tester, status: RideStatus.confirmed);
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    });
  });
}
