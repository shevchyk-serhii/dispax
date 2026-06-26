// Regression for the pull-to-refresh bug on the dispatcher pending panel:
//
// RefreshIndicator.onRefresh dispatched RideLoadPendingRequested and returned
// immediately, so the spinner dismissed before the reload finished — false
// "done" feedback over stale data. onRefresh must now await the bloc leaving
// the `loading` state, keeping the indicator up until the data actually lands.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
import 'package:dispax/dashboard/dispatcher/widgets/pending_rides_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  late MockRideService mockRideService;
  late MockScheduleService mockScheduleService;
  late MockApiClient mockApiClient;
  late RideBloc rideBloc;
  late ScheduleBloc scheduleBloc;
  late AuthBloc authBloc;

  final pendingRide = TestFixtures.ride(
    id: 'ride-1',
    status: RideStatus.requested,
    pickupDateTime: DateTime(2026, 3, 15, 10, 0),
  );

  setUp(() {
    mockRideService = MockRideService();
    mockScheduleService = MockScheduleService();
    mockApiClient = MockApiClient();
    when(() => mockRideService.dispose()).thenReturn(null);
    when(
      () => mockScheduleService.getScheduleForDate(any()),
    ).thenAnswer((_) async => [TestFixtures.scheduleDay(driverId: 'driver-1')]);
    // The client avatar fetches bytes; return null so it falls back to initials.
    when(() => mockApiClient.getBytes(any())).thenAnswer((_) async => null);

    rideBloc = RideBloc(rideService: mockRideService);
    scheduleBloc = ScheduleBloc(scheduleService: mockScheduleService);
    authBloc = AuthBloc(apiClient: mockApiClient);
  });

  tearDown(() {
    rideBloc.close();
    scheduleBloc.close();
    authBloc.close();
  });

  Widget buildPanel() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<RideBloc>.value(value: rideBloc),
            BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const PendingRidesPanel(),
        ),
      ),
    );
  }

  testWidgets('pull-to-refresh keeps the spinner until the reload completes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // initState load resolves immediately with one pending ride.
    when(
      () => mockRideService.getPendingRides(),
    ).thenAnswer((_) async => [pendingRide]);

    await tester.pumpWidget(buildPanel());
    // RideBloc delivers getPendingRides() across a real async hop, so drain
    // the event loop until the list (and its RefreshIndicator) is built.
    await _pumpUntilFound(tester, find.byType(RefreshIndicator));

    // The list rendered (non-empty -> RefreshIndicator is present).
    expect(find.byType(RefreshIndicator), findsOneWidget);

    // The refresh load is held open by a completer so we can observe the
    // indicator while the reload is in flight.
    final reload = Completer<List<Ride>>();
    when(
      () => mockRideService.getPendingRides(),
    ).thenAnswer((_) => reload.future);

    // Trigger pull-to-refresh.
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump(); // start the drag settle
    await tester.pump(const Duration(milliseconds: 200));

    // Advance well past the indicator's own snap-back animation while the
    // reload future is still pending. With the bug (onRefresh returns
    // immediately) the indicator finishes its animation and retracts here;
    // with the fix it must stay because onRefresh is still awaiting the
    // reload. 3s >> the ~1s RefreshIndicator animation.
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.byType(RefreshProgressIndicator),
      findsOneWidget,
      reason:
          'The refresh spinner retracted before the reload completed — '
          'onRefresh must await the load leaving the loading state.',
    );

    // Complete the reload -> the indicator retracts.
    reload.complete([pendingRide]);
    await tester.pumpAndSettle();

    expect(find.byType(RefreshProgressIndicator), findsNothing);

    // The reload actually happened (initState + the refresh).
    verify(() => mockRideService.getPendingRides()).called(greaterThan(1));
  });
}

/// Pumps repeatedly until [finder] matches, draining the real event loop
/// between pumps (RideBloc resolves across real async hops).
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 60,
}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  fail('Timed out waiting for: ${finder.describeMatch(Plurality.zero)}');
}
