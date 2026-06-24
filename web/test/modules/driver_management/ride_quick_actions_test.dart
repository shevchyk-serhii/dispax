import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/driver_management/widgets/ride_quick_actions.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _loc = Location(address: 'Maximilianstraße 10, 80539 München');

Ride _ride(RideStatus status) => Ride(
  id: 'ride-1',
  clientId: 'client-1',
  creatorId: 'creator-1',
  companyId: 'company-1',
  pickupDateTime: DateTime(2026, 6, 24, 10),
  from: _loc,
  to: _loc,
  clientName: 'BMW AG - Herr Schneider',
  status: status,
);

/// Pumps [RideQuickActions] with the localization delegates it requires
/// (the widget calls `AppLocalizations.of(context)!` in `build`).
Future<void> _pump(WidgetTester tester, Ride ride) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: RideQuickActions(
          ride: ride,
          onCallClient: () {},
          onStartRide: () {},
          onCompleteRide: () {},
          onConfirmRide: () {},
          onRejectRide: () {},
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
  group('RideQuickActions — Start Ride button styling', () {
    // Locks the unified Start-button look: accent colour + play_circle icon.
    // Guards against the divergent `success`/`play_arrow_rounded` variant.
    testWidgets('confirmed ride: accent-coloured play_circle Start button', (
      tester,
    ) async {
      await _pump(tester, _ride(RideStatus.confirmed));

      // The unified icon is play_circle (not play_arrow).
      expect(find.byIcon(Icons.play_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      // Localized "Start" label.
      expect(find.text('Start'), findsOneWidget);

      // The status button uses the corporate accent colour, not success.
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.byIcon(Icons.play_circle_rounded),
          matching: find.byType(ElevatedButton),
        ),
      );
      final bg = button.style?.backgroundColor?.resolve(<WidgetState>{});
      expect(bg, AppColors.accent);
    });

    testWidgets('assigned ride: Confirm + Reject, no Start button', (
      tester,
    ) async {
      await _pump(tester, _ride(RideStatus.assigned));

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_rounded), findsNothing);
    });
  });
}
