import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/driver_management/widgets/today_ride_card.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _loc = Location(address: 'Somewhere');

/// Minimal [Ride] fixture — only the fields relevant to ETA gating vary.
Ride _ride({required RideStatus status, int? etaMinutes}) {
  return Ride(
    id: 'ride-1',
    clientId: 'client-1',
    creatorId: 'creator-1',
    companyId: 'company-1',
    pickupDateTime: DateTime(2026, 6, 23, 10, 0),
    from: _loc,
    to: _loc,
    clientName: 'Test Client',
    status: status,
    etaMinutes: etaMinutes,
  );
}

/// Pumps [TodayRideCard] inside a [MaterialApp]+[Scaffold].
///
/// [onViewDetails] is stubbed to a no-op so the card's tap handler never
/// attempts a Navigator.push (which would require a full route stack).
Future<void> _pump(WidgetTester tester, Ride ride, {int? etaMinutes}) {
  return tester.pumpWidget(
    MaterialApp(
      // TodayRideCard reads AppLocalizations.of(context); without these
      // delegates that returns null and the card throws on build.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: TodayRideCard(
          ride: ride,
          etaMinutes: etaMinutes,
          onViewDetails: () {},
        ),
      ),
    ),
  );
}

// The ETA badge text is rendered as "~<n> min" (two separate Text widgets:
// "~<n>" and "min" are joined but Flutter text splitting may vary — check for
// the combined substring).
Finder _etaText(int minutes) => find.textContaining('~$minutes min');

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TodayRideCard — ETA badge gating by ride status', () {
    // Case 1 — regression guard: assigned + ETA must NOT show the badge.
    testWidgets(
      'assigned status with non-null etaMinutes: ETA badge is hidden',
      (tester) async {
        final ride = _ride(status: RideStatus.assigned, etaMinutes: 8);
        await _pump(tester, ride, etaMinutes: 8);

        // The badge must be absent for assigned rides.
        expect(
          _etaText(8),
          findsNothing,
          reason:
              'ETA badge must not appear while the ride is in assigned status — '
              'it is only meaningful after the driver starts the ride',
        );
        // Also check the icon is not shown.
        expect(find.byIcon(Icons.timer_outlined), findsNothing);
      },
    );

    // Case 2 — happy path: inProgress + ETA must show the badge.
    testWidgets(
      'inProgress status with non-null etaMinutes: ETA badge is shown',
      (tester) async {
        final ride = _ride(status: RideStatus.inProgress, etaMinutes: 12);
        await _pump(tester, ride, etaMinutes: 12);

        expect(
          _etaText(12),
          findsOneWidget,
          reason:
              'ETA badge must be visible once the ride is in inProgress status',
        );
        expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      },
    );

    // Case 3 — optional edge case: assigned with null ETA must render without error.
    testWidgets(
      'assigned status with null etaMinutes: card renders without error',
      (tester) async {
        final ride = _ride(status: RideStatus.assigned);
        await _pump(tester, ride);

        // No ETA badge in any form.
        expect(find.byIcon(Icons.timer_outlined), findsNothing);
        // The card itself must still be present (status label is uppercase via
        // RideStatusStyles.getStatusLabel).
        expect(find.textContaining('ASSIGNED'), findsWidgets);
      },
    );

    // Mutation check: inProgress with null etaMinutes must NOT show the badge,
    // verifying the etaMinutes != null guard is also active (not just the
    // status check). This is the complementary case that would catch a
    // regression where only the status check is removed but null check remains.
    testWidgets('inProgress status with null etaMinutes: ETA badge is hidden', (
      tester,
    ) async {
      final ride = _ride(status: RideStatus.inProgress);
      await _pump(tester, ride);

      expect(find.byIcon(Icons.timer_outlined), findsNothing);
    });
  });
}
