// Regression test for readable day columns in the driver calendar week view.
//
// Feature: the seven day columns must stay wide enough for the ride-block text
// (time / client / destination) to be readable. Before the fix all seven
// columns were squeezed to fit the screen width via `Expanded`, so on a narrow
// screen each column collapsed to ~110px and the block text was truncated to
// "Unkn…" / "Flugha…".
//
// The fix gives each column a minimum width (140px) and wraps the grid in a
// horizontal scroll view, so a narrow screen scrolls instead of squeezing,
// while a wide screen still fills the available width.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dispax/dashboard/driver/calendar/week_view_widget.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';

import '../../../helpers/test_fixtures.dart';

const double _minDayColumnWidth = 140;
const double _timeColumnWidth = 60;

// The week-view card has a 16px margin on every side, so the layout width is the
// viewport minus 32px before the columns are sized.
const double _cardHorizontalMargin = 32;

void main() {
  final selectedDay = DateTime(2026, 6, 26, 12, 0);
  final ride = TestFixtures.ride(
    id: 'r1',
    driverId: 'A',
    pickupDateTime: selectedDay,
  );

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekViewWidget(
            selectedDay: selectedDay,
            onDaySelected: _noopDate,
            onWeekChanged: _noopDate,
            ridesOverride: <Ride>[ride],
            onRideSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The whole grid (time gutter + 7 day columns) lives inside the single
  // horizontal-scroll SizedBox, whose width is 60 + 7 * columnWidth. Measuring
  // it recovers the per-column width without disambiguating identical columns.
  double gridWidth(WidgetTester tester) {
    final scroll = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(scroll, findsOneWidget);
    final inner = find.descendant(of: scroll, matching: find.byType(SizedBox));
    return tester.getSize(inner.first).width;
  }

  double columnWidthFromGrid(WidgetTester tester) =>
      (gridWidth(tester) - _timeColumnWidth) / 7;

  testWidgets(
    'narrow screen keeps columns at the minimum width (not squeezed)',
    (tester) async {
      // 360px wide: a fit-to-screen layout would give (360-60)/7 ≈ 43px columns.
      await pumpAt(tester, const Size(360, 1600));

      // Columns clamp to the minimum width, far wider than the ~43px a squeezed
      // fit-to-screen column would produce → the grid scrolls horizontally.
      expect(columnWidthFromGrid(tester), closeTo(_minDayColumnWidth, 0.5));
      expect(gridWidth(tester), greaterThan(360));
    },
  );

  testWidgets('wide screen fills the available width (columns wider than min)', (
    tester,
  ) async {
    // 1400px wide: (1400-60)/7 ≈ 191px per column, well above the 140 minimum.
    await pumpAt(tester, const Size(1400, 1600));

    final expectedColumn =
        (1400 - _cardHorizontalMargin - _timeColumnWidth) / 7;
    expect(columnWidthFromGrid(tester), greaterThan(_minDayColumnWidth));
    expect(columnWidthFromGrid(tester), closeTo(expectedColumn, 1));
  });
}

void _noopDate(DateTime _) {}
