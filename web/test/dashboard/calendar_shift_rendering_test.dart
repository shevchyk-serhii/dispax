// Shift (work-schedule) rendering in the calendar grid views: the week view
// draws a translucent availability band behind the ride blocks, the day view
// shows availability chips under the header, and the month view marks days
// carrying a shift with a small green bar.

import 'package:dispax/dashboard/driver/calendar/day_view_widget.dart';
import 'package:dispax/dashboard/driver/calendar/month_view_widget.dart';
import 'package:dispax/dashboard/driver/calendar/week_view_widget.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/schedule_management/models/schedule_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 7, 2);

  ScheduleDay shift({
    String id = 'shift-1',
    DateTime? date,
    String start = '14:00',
    String end = '22:00',
  }) {
    return ScheduleDay(
      id: id,
      driverId: 'driver-1',
      companyId: 'company-1',
      date: date ?? day,
      startTime: start,
      endTime: end,
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
  }

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );

  group('WeekViewWidget shift bands', () {
    testWidgets('renders a band for the shift day with its time range', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrap(
          WeekViewWidget(
            selectedDay: day,
            onDaySelected: (_) {},
            onWeekChanged: (_) {},
            ridesOverride: const [],
            shifts: [shift()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shift-band-shift-1')), findsOneWidget);
      expect(find.text('14:00–22:00'), findsOneWidget);
    });

    testWidgets('no band without shifts', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrap(
          WeekViewWidget(
            selectedDay: day,
            onDaySelected: (_) {},
            onWeekChanged: (_) {},
            ridesOverride: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shift-band-shift-1')), findsNothing);
    });

    testWidgets('a shift on another week day renders in that column only', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrap(
          WeekViewWidget(
            selectedDay: day,
            onDaySelected: (_) {},
            onWeekChanged: (_) {},
            ridesOverride: const [],
            shifts: [
              shift(id: 's-fri', date: DateTime(2026, 7, 3)),
              // Outside the shown week — must not render at all.
              shift(id: 's-next-week', date: DateTime(2026, 7, 10)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shift-band-s-fri')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shift-band-s-next-week')),
        findsNothing,
      );
    });
  });

  group('DayViewWidget shift chips', () {
    testWidgets('shows the availability chip for the selected day', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DayViewWidget(
            selectedDay: day,
            onRideSelected: (_) {},
            ridesOverride: const [],
            shifts: [shift()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('day-shift-shift-1')), findsOneWidget);
      expect(find.textContaining('Shift 14:00–22:00'), findsOneWidget);
    });

    testWidgets('shifts of other days are not shown', (tester) async {
      await tester.pumpWidget(
        wrap(
          DayViewWidget(
            selectedDay: day,
            onRideSelected: (_) {},
            ridesOverride: const [],
            shifts: [shift(date: DateTime(2026, 7, 4))],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('day-shift-shift-1')), findsNothing);
    });
  });

  group('MonthViewWidget shift markers', () {
    testWidgets('marks a day that has a shift even without rides', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: SizedBox(
              height: 600,
              child: MonthViewWidget(
                selectedDay: day,
                onDaySelected: (_) {},
                onMonthChanged: (_) {},
                ridesOverride: const [],
                shifts: [shift()],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('month-shift-2026-7-2')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('month-shift-2026-7-3')), findsNothing);
    });
  });
}
