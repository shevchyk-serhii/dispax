import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/driver_management/widgets/today_ride_card.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _loc = Location(address: 'Maximilianstraße 10, 80539 München');

/// Minimal [Ride] fixture for the header-overflow regression.
///
/// [pickupDateTime] defaults to the near future so the card treats the ride as
/// "upcoming" and renders the "Soon" badge (it requires `< 2h` until pickup).
Ride _ride({
  required RideStatus status,
  int? etaMinutes,
  required DateTime pickupDateTime,
}) {
  return Ride(
    id: 'ride-1',
    clientId: 'client-1',
    creatorId: 'creator-1',
    companyId: 'company-1',
    pickupDateTime: pickupDateTime,
    from: _loc,
    to: _loc,
    clientName: 'BMW AG - Herr Schneider',
    status: status,
    etaMinutes: etaMinutes,
  );
}

/// Pumps [TodayRideCard] at a fixed narrow logical width (~iPhone) so the
/// header row has the same tight horizontal budget that triggers the overflow
/// in the real app. [onViewDetails] is stubbed so the tap handler never pushes
/// a route.
Future<void> _pumpNarrow(
  WidgetTester tester,
  Ride ride, {
  int? approachingDistanceMeters,
  int? etaMinutes,
}) {
  // Logical 390 px wide (iPhone-class) — narrow enough that all chips + the
  // status pill cannot fit on one line without flexing.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      // TodayRideCard -> RideQuickActions reads AppLocalizations.of(context)!,
      // so the localization delegates must be present or build() throws.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: TodayRideCard(
          ride: ride,
          approachingDistanceMeters: approachingDistanceMeters,
          etaMinutes: etaMinutes,
          onViewDetails: () {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TodayRideCard — header chip-row overflow', () {
    // Regression guard reproducing the on-device screenshot: an in-progress
    // ride that simultaneously shows the "Soon", distance and ETA chips next to
    // the "IN PROGRESS" status pill on a narrow screen.
    testWidgets(
      'all chips + status pill on a narrow screen: no RenderFlex overflow',
      (tester) async {
        final ride = _ride(
          status: RideStatus.inProgress,
          etaMinutes: 4,
          // Near future → "Soon" badge (requires upcoming && < 2h to pickup).
          pickupDateTime: DateTime.now().add(const Duration(minutes: 3)),
        );

        await _pumpNarrow(
          tester,
          ride,
          approachingDistanceMeters: 368,
          etaMinutes: 4,
        );

        // A RenderFlex overflow surfaces as a thrown FlutterError caught by the
        // test binding. If the header row overflows, this is non-null.
        expect(
          tester.takeException(),
          isNull,
          reason:
              'The header chip row must not overflow when the time, "Soon", '
              'distance and ETA chips are shown alongside the status pill on a '
              'narrow screen',
        );
      },
    );

    // Sanity: with all chips present, every chip is actually rendered (the fix
    // must not drop chips to dodge the overflow).
    testWidgets('all chips are rendered when their conditions hold', (
      tester,
    ) async {
      final ride = _ride(
        status: RideStatus.inProgress,
        etaMinutes: 4,
        pickupDateTime: DateTime.now().add(const Duration(minutes: 3)),
      );

      await _pumpNarrow(
        tester,
        ride,
        approachingDistanceMeters: 368,
        etaMinutes: 4,
      );

      expect(find.text('Soon'), findsOneWidget);
      expect(find.textContaining('368m'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    });
  });
}
