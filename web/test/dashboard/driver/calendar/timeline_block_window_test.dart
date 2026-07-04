// Regression tests: ride/busy blocks must be clipped into the visible
// 06:00–23:00 window the same way shift regions already are.
//
// The bugs (audit 2026-07-02): the week view positioned a ride block at
// `top = (startHour − 6) * 40` WITHOUT clamping — a 02:00 ride rendered at
// top = −160, above the grid; and the shared DayTimeline clamped a block's
// start and end independently, so a busy slot crossing midnight
// (22:00→00:30) produced `bottom < top` and collapsed into a 10 px stub at
// the bottom edge instead of the 22:00–23:00 evening band.

import 'package:dispax/dashboard/driver/calendar/day_timeline.dart';
import 'package:dispax/dashboard/driver/calendar/week_view_widget.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('DayTimeline blocks', () {
    TimelineBlock block(String key, double start, double end) => TimelineBlock(
      keyValue: key,
      startHour: start,
      endHour: end,
      color: Colors.blueGrey,
      borderColor: Colors.blueGrey,
      content: const SizedBox.shrink(),
    );

    testWidgets(
      'a busy slot crossing midnight (22:00→00:30) renders as the evening '
      'band, not a 10 px stub',
      (tester) async {
        useTallViewport(tester);
        await tester.pumpWidget(
          wrap(
            SizedBox(
              height: 692, // 680 inner grid + 12 vertical padding
              width: 220,
              child: DayTimeline(
                shiftRegions: const [],
                blocks: [block('busy-midnight', 22, 0.5)],
              ),
            ),
          ),
        );

        final timelineRect = tester.getRect(find.byType(DayTimeline));
        final blockRect = tester.getRect(
          find.byKey(const ValueKey('busy-midnight')),
        );

        // Fully inside the grid…
        expect(blockRect.top, greaterThanOrEqualTo(timelineRect.top));
        expect(blockRect.bottom, lessThanOrEqualTo(timelineRect.bottom));
        // …and roughly one hour tall (≈ 1/17 of the 680 px grid ≈ 40 px),
        // not the 10 px minimum stub the bottom<top collapse produced.
        expect(blockRect.height, closeTo(680 / 17, 1.5));
      },
    );

    testWidgets('a 02:00 ride pins inside the grid instead of overflowing '
        'above it', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        wrap(
          SizedBox(
            height: 692,
            width: 220,
            child: DayTimeline(
              shiftRegions: const [],
              blocks: [block('night-ride', 2, 3.5)],
            ),
          ),
        ),
      );

      final timelineRect = tester.getRect(find.byType(DayTimeline));
      final blockRect = tester.getRect(
        find.byKey(const ValueKey('night-ride')),
      );

      expect(
        blockRect.top,
        greaterThanOrEqualTo(timelineRect.top),
        reason: 'the block must not render above the grid',
      );
      expect(blockRect.bottom, lessThanOrEqualTo(timelineRect.bottom));
    });
  });

  group('WeekViewWidget ride blocks', () {
    testWidgets('a 02:00 ride renders inside the 06–23 grid, not at −160 px '
        'above it', (tester) async {
      useTallViewport(tester);
      final day = DateTime(2026, 7, 6);
      final ride = TestFixtures.ride(
        id: 'night-1',
        pickupDateTime: DateTime(2026, 7, 6, 2, 0),
      );

      await tester.pumpWidget(
        wrap(
          WeekViewWidget(
            selectedDay: day,
            onDaySelected: (_) {},
            onWeekChanged: (_) {},
            ridesOverride: [ride],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final positioned = tester.widget<Positioned>(
        find.byKey(const ValueKey('week-ride-night-1')),
      );
      expect(
        positioned.top,
        greaterThanOrEqualTo(0.0),
        reason: 'a pre-window ride used to get top = (2 − 6) * 40 = −160',
      );
      final top = positioned.top!;
      final height = positioned.height!;
      expect(top + height, lessThanOrEqualTo(17 * 40.0));
    });

    testWidgets('a 22:30 ride is clipped to the grid bottom', (tester) async {
      useTallViewport(tester);
      final day = DateTime(2026, 7, 6);
      final ride = TestFixtures.ride(
        id: 'late-1',
        pickupDateTime: DateTime(2026, 7, 6, 22, 30),
      );

      await tester.pumpWidget(
        wrap(
          WeekViewWidget(
            selectedDay: day,
            onDaySelected: (_) {},
            onWeekChanged: (_) {},
            ridesOverride: [ride],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final positioned = tester.widget<Positioned>(
        find.byKey(const ValueKey('week-ride-late-1')),
      );
      final top = positioned.top!;
      final height = positioned.height!;
      // 22:30 + nominal 1.5 h crosses the 23:00 window end — the block must
      // stop at the grid bottom (17 rows × 40 px) instead of overflowing it.
      expect(top + height, lessThanOrEqualTo(17 * 40.0));
      expect(top, closeTo((22.5 - 6) * 40.0, 0.001));
    });
  });
}
