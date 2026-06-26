// Regression test for tappable ride blocks in the driver calendar week view.
//
// Feature: in the Week view, ride blocks rendered on the time grid must be
// tappable and invoke `onRideSelected` so the schedule screen can open the
// ride details screen — the same behaviour Day view and Board already have.
//
// Before the fix the block was a bare Tooltip with no gesture handler, so
// tapping it did nothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dispax/dashboard/driver/calendar/week_view_widget.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  // Friday inside the rendered 06:00–22:00 grid window.
  final selectedDay = DateTime(2026, 6, 26, 12, 0);
  final ride = TestFixtures.ride(
    id: 'r1',
    driverId: 'A',
    pickupDateTime: selectedDay,
  );

  testWidgets('tapping a week ride block fires onRideSelected with that ride', (
    tester,
  ) async {
    // The week grid is tall (17 * 40px); give it room so the block is laid out
    // and hit-testable.
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Ride? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekViewWidget(
            selectedDay: selectedDay,
            onDaySelected: _noopDate,
            onWeekChanged: _noopDate,
            ridesOverride: <Ride>[ride],
            onRideSelected: (r) => tapped = r,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The block shows the client name (unique to the block; the "12:00" time
    // label also appears in the left time column, so it is ambiguous). Tap the
    // block's GestureDetector via the client-name text.
    final clientLabel = find.text('Test Client');
    expect(clientLabel, findsOneWidget);
    await tester.tap(clientLabel, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tapped, isNotNull);
    expect(tapped!.id, 'r1');
  });
}

void _noopDate(DateTime _) {}
