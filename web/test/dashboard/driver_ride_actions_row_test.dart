import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

/// Pumps [DriverRideActionsRow] for a ride in [status] inside a narrow,
/// width-constrained card so the regression (action labels overflowing or
/// truncating on small screens) would surface.
Future<void> pumpActionsRow(
  WidgetTester tester, {
  required RideStatus status,
  double width = 360,
  VoidCallback? onShareRide,
  Locale? locale,
}) async {
  final ride = TestFixtures.ride(driverId: 'driver-1', status: status);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
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

/// Returns true when the [Text] found by [textFinder] was clipped by its
/// `TextOverflow.ellipsis` — i.e. the label did not fit and shows "Navigie…".
/// A plain `takeException()` check does NOT catch this: ellipsis truncation is
/// "legal" layout and raises no RenderFlex exception, which is exactly why the
/// original single-row design shipped with truncated German labels.
bool _isTruncated(WidgetTester tester, Finder textFinder) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: textFinder, matching: find.byType(RichText)),
  );
  return paragraph.didExceedMaxLines;
}

void main() {
  group('DriverRideActionsRow', () {
    testWidgets(
      'assigned: shows Confirm and Reject without overflowing a narrow card',
      (tester) async {
        await pumpActionsRow(tester, status: RideStatus.assigned, width: 320);

        // Both primary actions are present and fully laid out (English default).
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

    testWidgets(
      'assigned: localizes Confirm/Reject in German (not hardcoded English)',
      (tester) async {
        await pumpActionsRow(
          tester,
          status: RideStatus.assigned,
          locale: const Locale('de'),
        );

        // The labels must come from l10n: German renders "Bestätigen"/"Ablehnen".
        expect(find.text('Bestätigen'), findsOneWidget);
        expect(find.text('Ablehnen'), findsOneWidget);
        // The old hardcoded English strings must be gone on a German UI.
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);
      },
    );

    testWidgets(
      'assigned: German labels are not truncated on a phone-narrow card',
      (tester) async {
        // 320px is narrower than the phone in the bug report. With the buttons
        // on a single row the German "Navigieren"/"Bestätigen"/"Ablehnen" got
        // clipped to "Navigie…"/"Bestäti…"; the two-row layout must show them
        // in full.
        await pumpActionsRow(
          tester,
          status: RideStatus.assigned,
          width: 320,
          locale: const Locale('de'),
        );

        expect(_isTruncated(tester, find.text('Navigieren')), isFalse);
        expect(_isTruncated(tester, find.text('Bestätigen')), isFalse);
        expect(_isTruncated(tester, find.text('Ablehnen')), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

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

    testWidgets(
      'icon-only Call/Share buttons carry a hover tooltip with a label',
      (tester) async {
        await pumpActionsRow(
          tester,
          status: RideStatus.assigned,
          onShareRide: () {},
        );

        // The phone and share icons have no visible text, so a tooltip is the
        // only way to learn what they do on hover.
        final callTooltip = find.ancestor(
          of: find.byIcon(Icons.phone_outlined),
          matching: find.byType(Tooltip),
        );
        final shareTooltip = find.ancestor(
          of: find.byIcon(Icons.ios_share_rounded),
          matching: find.byType(Tooltip),
        );
        expect(callTooltip, findsOneWidget);
        expect(shareTooltip, findsOneWidget);

        expect(tester.widget<Tooltip>(callTooltip).message, isNotEmpty);
        expect(tester.widget<Tooltip>(shareTooltip).message, isNotEmpty);
      },
    );
  });
}
