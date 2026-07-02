// RideStatusStyles.getStatusDisplayName returned hardcoded English, so status
// badges stayed English when the user picked German. The badge now reads the
// localized label from the BuildContext. This locks the German labels.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/utils/ride_status_styles.dart';

void main() {
  Widget badge(RideStatus status) => MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) =>
            RideStatusStyles.createStatusBadge(status, context: context),
      ),
    ),
  );

  testWidgets('requested badge is German', (tester) async {
    await tester.pumpWidget(badge(RideStatus.requested));
    await tester.pump();
    expect(find.text('Angefordert'), findsOneWidget); // Requested
    expect(find.text('Requested'), findsNothing);
  });

  testWidgets('in-progress badge is German', (tester) async {
    await tester.pumpWidget(badge(RideStatus.inProgress));
    await tester.pump();
    expect(find.text('In Bearbeitung'), findsOneWidget); // In Progress
    expect(find.text('In Progress'), findsNothing);
  });

  testWidgets('handed-off badge is German', (tester) async {
    await tester.pumpWidget(badge(RideStatus.handedOff));
    await tester.pump();
    expect(find.text('Übergeben'), findsOneWidget); // Handed Off
    expect(find.text('Handed Off'), findsNothing);
  });

  // Without a localizer (no context) the English fallback is preserved so
  // legacy callers don't crash.
  test('falls back to English when no localizer is passed', () {
    expect(
      RideStatusStyles.getStatusDisplayName(RideStatus.requested),
      'Requested',
    );
    expect(
      RideStatusStyles.getStatusLabel(RideStatus.inProgress),
      'IN PROGRESS',
    );
  });
}
