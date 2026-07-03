// The calendar day view must show the same vertical hour-scale timeline the
// week view / board have: the day's shift stretches as a translucent green
// availability region and rides sit on it as tappable time blocks. Before this
// change the day view showed only a chip and, with no rides, collapsed to the
// "No rides scheduled" empty state even when a shift existed.

import 'package:dispax/dashboard/driver/calendar/day_timeline.dart';
import 'package:dispax/dashboard/driver/calendar/day_view_widget.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/schedule_management/models/schedule_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  final day = DateTime(2026, 7, 3);

  ScheduleDay shift({String id = 'shift-1'}) => ScheduleDay(
    id: id,
    driverId: 'driver-1',
    companyId: 'company-1',
    date: day,
    startTime: '08:00',
    endTime: '16:00',
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'a shift day without rides shows the timeline with the availability region',
    (tester) async {
      useTallViewport(tester);
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

      expect(find.byType(DayTimeline), findsOneWidget);
      expect(
        find.byKey(const ValueKey('day-tl-shift-shift-1')),
        findsOneWidget,
      );
      // The shift region carries its time range, like the week view band.
      expect(find.text('08:00–16:00'), findsWidgets);
    },
  );

  testWidgets('a ride renders as a tappable block on the timeline', (
    tester,
  ) async {
    useTallViewport(tester);
    final ride = TestFixtures.ride(
      id: 'ride-1',
      pickupDateTime: DateTime(2026, 7, 3, 10, 30),
    );
    Ride? tapped;

    await tester.pumpWidget(
      wrap(
        DayViewWidget(
          selectedDay: day,
          onRideSelected: (r) => tapped = r,
          ridesOverride: [ride],
          shifts: [shift()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final block = find.byKey(const ValueKey('day-tl-ride-ride-1'));
    expect(block, findsOneWidget);

    await tester.tap(block);
    expect(tapped?.id, 'ride-1');
  });

  testWidgets('no shifts and no rides keeps the empty state, no timeline', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(
      wrap(
        DayViewWidget(
          selectedDay: day,
          onRideSelected: (_) {},
          ridesOverride: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DayTimeline), findsNothing);
    expect(find.text('No rides scheduled'), findsOneWidget);
  });
}
