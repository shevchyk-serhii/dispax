// Widget tests for the arrivals-board date selector: prev/next arrows fire their
// callbacks, the date label renders, and tapping the label opens the date picker.

import 'package:dispax/dashboard/dispatcher/arrivals_board_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the date label and fires prev/next', (tester) async {
    var prev = 0;
    var next = 0;
    await pump(
      tester,
      ArrivalsDateBar(
        date: DateTime(2026, 6, 28),
        onPrev: () => prev++,
        onNext: () => next++,
        onTap: () {},
      ),
    );

    // en default locale → "Sun, 28 Jun".
    expect(find.textContaining('28'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(prev, 1);
    expect(next, 1);
  });

  testWidgets('tapping the date fires onTap (opens picker)', (tester) async {
    var tapped = 0;
    await pump(
      tester,
      ArrivalsDateBar(
        date: DateTime(2026, 6, 28),
        onPrev: () {},
        onNext: () {},
        onTap: () => tapped++,
      ),
    );

    await tester.tap(find.byIcon(Icons.calendar_today));
    expect(tapped, 1);
  });
}
