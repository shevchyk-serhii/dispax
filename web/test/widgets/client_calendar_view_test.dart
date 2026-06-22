// Tests for ClientCalendarView.
//
// Verifies:
//   1. Default view is month — MonthViewWidget is rendered.
//   2. Switching to 'Week' segment renders WeekViewWidget.
//   3. Switching to 'Day' segment renders ClientDayViewWidget.
//   4. CalendarControls next/prev arrows update the displayed period label.
//   5. Navigation increments/decrements correctly per view type.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/client/calendar/client_calendar_view.dart';
import 'package:dispax/dashboard/client/calendar/client_day_view_widget.dart';
import 'package:dispax/dashboard/driver/calendar/month_view_widget.dart';
import 'package:dispax/dashboard/driver/calendar/week_view_widget.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _FakeRideEvent extends Fake implements RideEvent {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester, _MockRideBloc rideBloc) async {
  // Use a fixed viewport large enough that SegmentedButton fits without overflow.
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: BlocProvider<RideBloc>.value(
        value: rideBloc,
        child: const Scaffold(
          body: ClientCalendarView(onRideSelected: _noop),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _noop(dynamic _) {}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
  });

  late _MockRideBloc rideBloc;

  setUp(() {
    rideBloc = _MockRideBloc();
    when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
  });

  tearDown(() {
    // Physical size is reset by addTearDown inside each test.
  });

  // ── Default view ───────────────────────────────────────────────────────────

  group('ClientCalendarView — default view type', () {
    testWidgets('renders MonthViewWidget by default', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(tester, rideBloc);
      expect(find.byType(MonthViewWidget), findsOneWidget);
    });

    testWidgets('does not render WeekViewWidget or ClientDayViewWidget initially',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(tester, rideBloc);
      expect(find.byType(WeekViewWidget), findsNothing);
      expect(find.byType(ClientDayViewWidget), findsNothing);
    });
  });

  // ── View-type switching ────────────────────────────────────────────────────

  group('ClientCalendarView — view-type segmented button', () {
    testWidgets("tapping 'Week' segment switches to WeekViewWidget",
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(tester, rideBloc);

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      expect(find.byType(WeekViewWidget), findsOneWidget);
      expect(find.byType(MonthViewWidget), findsNothing);
    });

    testWidgets("tapping 'Day' segment switches to ClientDayViewWidget",
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(tester, rideBloc);

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      expect(find.byType(ClientDayViewWidget), findsOneWidget);
      expect(find.byType(MonthViewWidget), findsNothing);
    });

    testWidgets("tapping 'Month' after switching view returns to MonthViewWidget",
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(tester, rideBloc);

      // Switch to Day first, then back to Month.
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(find.byType(ClientDayViewWidget), findsOneWidget);

      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.byType(MonthViewWidget), findsOneWidget);
    });
  });

  // ── CalendarControls navigation in month view ──────────────────────────────

  group('ClientCalendarView — navigation in month view', () {
    testWidgets('next arrow advances the month by one', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(tester, rideBloc);
      // Make sure we are in month view (default).
      expect(find.byType(MonthViewWidget), findsOneWidget);

      // Read the current month label from CalendarControls.
      final now = DateTime.now();
      final currentMonthYear = _monthYear(now);
      // The month label may appear in both CalendarControls and
      // MonthViewWidget/TableCalendar header — at least one occurrence is enough.
      expect(find.text(currentMonthYear), findsWidgets);

      // Tap the next (chevron_right) button in CalendarControls.
      // Use .first because MonthViewWidget (TableCalendar) also contains
      // a chevron_right icon for its own header navigation.
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();

      final nextMonth = DateTime(now.year, now.month + 1, 1);
      // Next month appears somewhere in the tree.
      expect(find.text(_monthYear(nextMonth)), findsWidgets);
      // Current month label is no longer present.
      expect(find.text(currentMonthYear), findsNothing);
    });

    testWidgets('prev arrow goes back one month', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(tester, rideBloc);

      final now = DateTime.now();
      final currentMonthYear = _monthYear(now);
      expect(find.text(currentMonthYear), findsWidgets);

      // Use .first for the same reason as chevron_right above.
      await tester.tap(find.byIcon(Icons.chevron_left).first);
      await tester.pumpAndSettle();

      final prevMonth = DateTime(now.year, now.month - 1, 1);
      expect(find.text(_monthYear(prevMonth)), findsWidgets);
      expect(find.text(currentMonthYear), findsNothing);
    });
  });

  // ── CalendarControls navigation in day view ────────────────────────────────

  group('ClientCalendarView — navigation in day view', () {
    testWidgets('next arrow in day view advances by one day', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(tester, rideBloc);

      // Switch to Day view.
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final todayLabel = _dayLabel(now);
      expect(find.text(todayLabel), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      final tomorrow = now.add(const Duration(days: 1));
      expect(find.text(_dayLabel(tomorrow)), findsOneWidget);
      expect(find.text(todayLabel), findsNothing);
    });

    testWidgets('prev arrow in day view goes back one day', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(tester, rideBloc);

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final todayLabel = _dayLabel(now);
      expect(find.text(todayLabel), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      final yesterday = now.subtract(const Duration(days: 1));
      expect(find.text(_dayLabel(yesterday)), findsOneWidget);
      expect(find.text(todayLabel), findsNothing);
    });
  });
}

// ── Label helpers that mirror CalendarControls._getFormattedDate ─────────────

const _monthNames = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _dayNames = [
  '',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _monthYear(DateTime d) => '${_monthNames[d.month]} ${d.year}';

String _dayLabel(DateTime d) =>
    '${_dayNames[d.weekday]}, ${_monthNames[d.month]} ${d.day}, ${d.year}';
