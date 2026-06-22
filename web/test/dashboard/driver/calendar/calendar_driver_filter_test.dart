// Regression tests for the driver-aware calendar filter.
//
// Bug: when a dispatcher switched the driver in the schedule screen dropdown,
// the calendar kept showing the previous driver's ride markers. The month/week/
// day widgets read RideBloc.rides (all company rides for a dispatcher) and only
// filtered by date — never by the selected driver.
//
// Fix: the widgets take an optional `driverIdFilter`; getRidesForDay drops any
// ride not assigned to that driver. A null filter shows everything (back-compat).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/driver/calendar/month_view_widget.dart';
import 'package:dispax/dashboard/driver/calendar/week_view_widget.dart';
import 'package:dispax/dashboard/driver/calendar/day_view_widget.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';

import '../../../helpers/test_fixtures.dart';

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

void main() {
  final day = DateTime(2026, 6, 22, 10, 0);

  // Two drivers' rides on the SAME day, plus one ride on another day.
  final ridesAllDrivers = <Ride>[
    TestFixtures.ride(id: 'a1', driverId: 'A', pickupDateTime: day),
    TestFixtures.ride(id: 'a2', driverId: 'A', pickupDateTime: day),
    TestFixtures.ride(id: 'b1', driverId: 'B', pickupDateTime: day),
    TestFixtures.ride(
      id: 'a-other-day',
      driverId: 'A',
      pickupDateTime: DateTime(2026, 6, 23, 10, 0),
    ),
    TestFixtures.ride(id: 'unassigned', driverId: null, pickupDateTime: day),
  ];

  group('getRidesForDay driver filter', () {
    test('month: returns only the selected driver\'s rides for the day', () {
      final widget = MonthViewWidget(
        selectedDay: day,
        onDaySelected: _noopDate,
        onMonthChanged: _noopDate,
        driverIdFilter: 'A',
      );
      final result = widget.getRidesForDay(ridesAllDrivers, day);
      expect(result.map((r) => r.id), unorderedEquals(['a1', 'a2']));
    });

    test('month: switching the filter switches the rides', () {
      final widget = MonthViewWidget(
        selectedDay: day,
        onDaySelected: _noopDate,
        onMonthChanged: _noopDate,
        driverIdFilter: 'B',
      );
      final result = widget.getRidesForDay(ridesAllDrivers, day);
      expect(result.map((r) => r.id), ['b1']);
    });

    test('month: null filter shows all rides for the day (back-compat)', () {
      final widget = MonthViewWidget(
        selectedDay: day,
        onDaySelected: _noopDate,
        onMonthChanged: _noopDate,
      );
      final result = widget.getRidesForDay(ridesAllDrivers, day);
      expect(
        result.map((r) => r.id),
        unorderedEquals(['a1', 'a2', 'b1', 'unassigned']),
      );
    });

    test('week: filters by driver and date', () {
      final widget = WeekViewWidget(
        selectedDay: day,
        onDaySelected: _noopDate,
        onWeekChanged: _noopDate,
        driverIdFilter: 'A',
      );
      final result = widget.getRidesForDay(ridesAllDrivers, day);
      expect(result.map((r) => r.id), unorderedEquals(['a1', 'a2']));
    });

    test('day: filters by driver and date', () {
      final widget = DayViewWidget(
        selectedDay: day,
        onRideSelected: _noopRide,
        driverIdFilter: 'B',
      );
      final result = widget.getRidesForDay(ridesAllDrivers, day);
      expect(result.map((r) => r.id), ['b1']);
    });
  });

  // The month widget renders its markers entirely from getRidesForDay, so a
  // widget-level smoke test would collide with the day-number labels in the
  // calendar grid (e.g. the "22" cell). The unit tests above cover the actual
  // filtering logic that the bug lived in. We still assert the widget builds
  // with a filter set, to guard the constructor wiring.
  group('MonthViewWidget builds with a driver filter', () {
    testWidgets('renders without error when a filter is applied', (
      tester,
    ) async {
      final bloc = _MockRideBloc();
      when(() => bloc.state).thenReturn(RideState.loaded(ridesAllDrivers));
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<RideBloc>.value(
            value: bloc,
            child: Scaffold(
              body: MonthViewWidget(
                selectedDay: day,
                onDaySelected: _noopDate,
                onMonthChanged: _noopDate,
                driverIdFilter: 'A',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MonthViewWidget), findsOneWidget);
    });
  });
}

void _noopDate(DateTime _) {}
void _noopRide(Ride _) {}
