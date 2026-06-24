import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

/// Pumps a MaterialApp with an "open" button that shows [RejectRideDialog] and
/// records the reason it returns via Navigator.pop. The returned getter exposes
/// that reason — exactly the string that would feed RideRejectRequested.reason.
Future<String? Function()> _openDialog(WidgetTester tester) async {
  String? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => RejectRideDialog(
                    ride: TestFixtures.ride(driverId: 'driver-1'),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  group('RejectRideDialog', () {
    testWidgets('shows 5 preset chips and hides the custom field by default', (
      tester,
    ) async {
      await _openDialog(tester);

      expect(find.byType(ChoiceChip), findsNWidgets(5));
      // No free-text field until "Other" is picked.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Reject is disabled until a reason is chosen', (tester) async {
      await _openDialog(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(l10n.rejectButton),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping a preset chip returns its stable English reason', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final reason = await _openDialog(tester);

      // "Busy with another ride" preset.
      await tester.tap(find.text(l10n.rejectReasonBusy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.rejectButton));
      await tester.pumpAndSettle();

      expect(reason(), 'Busy with another ride');
    });

    testWidgets(
      'Other reveals a field; empty keeps Reject disabled, typed text '
      'is returned',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final reason = await _openDialog(tester);

        await tester.tap(find.text(l10n.rejectReasonOther));
        await tester.pumpAndSettle();

        // Field appears, but Reject stays disabled while it is empty.
        expect(find.byType(TextField), findsOneWidget);
        final disabled = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text(l10n.rejectButton),
            matching: find.byType(FilledButton),
          ),
        );
        expect(disabled.onPressed, isNull);

        await tester.enterText(find.byType(TextField), 'Sick today');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.rejectButton));
        await tester.pumpAndSettle();

        expect(reason(), 'Sick today');
      },
    );
  });
}
