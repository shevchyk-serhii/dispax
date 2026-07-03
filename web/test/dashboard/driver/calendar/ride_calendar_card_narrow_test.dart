// Regression: the day-view ride card header (time + duration + price on the
// left, status badge on the right) overflowed horizontally when the card is
// narrow — e.g. next to the day view's hour timeline. The left group now
// scales down (Flexible + FittedBox) instead of overflowing.

import 'package:dispax/dashboard/driver/calendar/widgets/ride_calendar_card.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  testWidgets('RideCalendarCard does not overflow at narrow widths', (
    tester,
  ) async {
    final ride = TestFixtures.ride(
      id: 'ride-1',
      pickupDateTime: DateTime(2026, 7, 3, 9, 0),
      price: 125.50,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 230,
              child: RideCalendarCard(
                ride: ride,
                onPriceEdited: (_) {},
                showActions: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: 'a narrow ride card must scale its header, not overflow',
    );
  });
}
