// Regression test for the dispatcher red-screen crash:
//
//   'package:flutter/src/widgets/framework.dart': Failed assertion: line 6161
//   pos 14: '_dependents.isEmpty': is not true.
//
// Reproduction on a real device: dispatcher screen -> tap a pending ride ->
// driver-selection bottom sheet -> pick a driver -> AssignmentDialog ->
// "Assign driver" / "Assign anyway". The dialog popped itself and then
// *synchronously* dispatched the RideAssign/Reassign event into the same
// RideBloc the panel listens to. The bloc immediately propagated a new state,
// which (re)built the panel's BlocListener/BlocBuilder subtree — and, on the
// conflict path, re-entrantly pushed the "Driver is busy" dialog — while the
// just-popped modal route was still being torn down. That mid-deactivation
// rebuild tripped Flutter's `InheritedElement.debugDeactivated`
// `_dependents.isEmpty` assertion and red-screened the dispatcher.
//
// Root cause, stated as a contract: the assignment must NOT be dispatched while
// the dialog route is still mounted. The fix defers the dispatch to a
// post-frame callback so `Navigator.pop()` finishes (the dialog leaves the
// tree) before any new bloc state propagates.
//
// This test drives the genuine UI path and asserts that contract directly:
// when `assignDriver` is invoked, the AssignmentDialog must already be gone.
// With the buggy synchronous dispatch the dialog is still in the tree at that
// moment (and the framework error capture would also catch any assertion); with
// the deferred fix it has been removed. The discriminator is deterministic in
// the widget-test scheduler, unlike the engine-frame-timing-dependent
// `_dependents.isEmpty` assertion itself.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/modules/core/widgets/avatar_circle.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
import 'package:dispax/dashboard/dispatcher/widgets/pending_rides_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
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

  // Snapshot of the tree at the instant the panel dispatches the assignment to
  // the bloc (i.e. when `assignDriver` is invoked). The crash happens precisely
  // when this dispatch lands while the AssignmentDialog route is still mounted,
  // so we record whether the dialog header is still present at that moment.
  late bool dialogStillMountedAtDispatch;

  // A single pending ride the dispatcher will try to assign. The driver has no
  // locally-detected clash, so the AssignmentDialog shows "Assign driver" and
  // dispatches with overrideScheduleConflict:false.
  final pendingRide = TestFixtures.ride(
    id: 'ride-1',
    status: RideStatus.requested,
    pickupDateTime: DateTime(2026, 3, 15, 10, 0),
  );

  setUp(() {
    mockRideService = MockRideService();
    mockScheduleService = MockScheduleService();
    mockApiClient = MockApiClient();
    dialogStillMountedAtDispatch = false;

    // initState() of the panel fires these two loads.
    when(
      () => mockRideService.getPendingRides(),
    ).thenAnswer((_) async => [pendingRide]);
    when(() => mockRideService.dispose()).thenReturn(null);
    when(
      () => mockScheduleService.getScheduleForDate(any()),
    ).thenAnswer((_) async => [TestFixtures.scheduleDay(driverId: 'driver-1')]);

    // The driver-selection sheet loads drivers through
    // UserService(apiClient: authBloc.apiClient).getDrivers() -> GET /users/drivers.
    when(() => mockApiClient.get('/users/drivers')).thenAnswer(
      (_) async => http.Response(
        '[{"id":"driver-1","name":"Driver Hans","email":"hans@example.com",'
        '"role":"driver","companyId":"company-1","phone":"+491111111111"}]',
        200,
      ),
    );

    // The moment the panel dispatches the assignment, record what is still in
    // the tree, then reject with a 409 so the conflict path (BlocListener ->
    // "Driver is busy" dialog) is also exercised end-to-end.
    when(
      () => mockRideService.assignDriver(
        any(),
        any(),
        overrideScheduleConflict: any(named: 'overrideScheduleConflict'),
      ),
    ).thenAnswer((_) async {
      dialogStillMountedAtDispatch = find
          .textContaining('Assign Ride')
          .evaluate()
          .isNotEmpty;
      throw ApiException(
        'Driver has a Lunch unavailability from 10:00 to 11:00',
        statusCode: 409,
      );
    });

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
      // The panel and its dialogs read AppLocalizations.of(context); without
      // these delegates that returns null and the conflict dialog never builds,
      // hanging pumpAndSettle for the full test timeout.
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

  testWidgets(
    'the driver-selection sheet renders each driver via AvatarCircle (photo '
    'when set), not a hardcoded person icon',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // This driver has a profile photo: getDrivers reports hasAvatar=true, and
      // the avatar endpoint serves bytes. AvatarCircle must fetch them.
      when(() => mockApiClient.get('/users/drivers')).thenAnswer(
        (_) async => http.Response(
          '[{"id":"driver-1","name":"Driver Hans","email":"hans@example.com",'
          '"role":"driver","companyId":"company-1","phone":"+491111111111",'
          '"hasAvatar":true}]',
          200,
        ),
      );
      when(
        () => mockApiClient.getBytes('/users/driver-1/avatar'),
      ).thenAnswer((_) async => Uint8List.fromList([0xFF, 0xD8, 0xFF]));

      await tester.pumpWidget(buildPanel());
      await _pumpUntilFound(tester, find.text('Assign'));
      await tester.tap(find.text('Assign').first);
      await _pumpUntilFound(tester, find.text('Select Driver'));
      await _pumpUntilFound(tester, find.text('Driver Hans'));

      // The row uses AvatarCircle (not a bare Icon(Icons.person) placeholder),
      // and AvatarCircle fetched the photo bytes for the driver with a photo.
      expect(find.byType(AvatarCircle), findsWidgets);
      verify(() => mockApiClient.getBytes('/users/driver-1/avatar')).called(1);
    },
  );

  testWidgets(
    'assigning a driver via the selection sheet + AssignmentDialog defers the '
    'dispatch until the dialog is gone (no mid-teardown rebuild)',
    (tester) async {
      // Use a tall surface so the bottom sheet's driver row and the dialog's
      // footer buttons are fully on-screen and hit-testable.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Capture any framework error raised during the dialog teardown /
      // dispatch (the `_dependents.isEmpty` assertion among them).
      final caught = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) => caught.add(details);
      addTearDown(() => FlutterError.onError = previousOnError);

      await tester.pumpWidget(buildPanel());
      await _pumpUntilFound(tester, find.text('Assign'));

      // The pending ride row shows an "Assign" action button.
      expect(find.text('Assign'), findsWidgets);

      // 1) Open the driver-selection bottom sheet.
      await tester.tap(find.text('Assign').first);
      await _pumpUntilFound(tester, find.text('Select Driver'));

      // 2) Pick the driver -> sheet pops, AssignmentDialog opens. The sheet
      // loads drivers asynchronously, so wait for the row and scroll it into
      // the hit-testable viewport before tapping.
      await _pumpUntilFound(tester, find.text('Driver Hans'));
      await tester.ensureVisible(find.text('Driver Hans'));
      // Bounded timeout so a future regression fails fast instead of hanging on
      // the default 10-minute pumpAndSettle budget.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      await tester.tap(find.text('Driver Hans'));
      await _pumpUntilFound(tester, find.textContaining('Assign Ride'));

      // No local clash -> dialog offers the plain "Assign driver".
      expect(find.text('Assign driver'), findsOneWidget);

      // 3) Confirm. This is where the crash struck.
      await tester.tap(find.text('Assign driver'));
      // Pump until the assignment has been dispatched and the resulting
      // conflict dialog appears (the bloc delivers across real async hops).
      await _pumpUntilFound(tester, find.text('Driver Busy'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );

      FlutterError.onError = previousOnError;

      // The assignment was actually dispatched...
      verify(
        () => mockRideService.assignDriver(
          'ride-1',
          'driver-1',
          overrideScheduleConflict: false,
        ),
      ).called(1);

      // ...and crucially, the dispatch landed only AFTER the AssignmentDialog
      // (and the driver-selection sheet) had left the tree. With the buggy
      // synchronous dispatch the dialog is still mounted at this instant — the
      // exact mid-deactivation rebuild that red-screens the dispatcher.
      expect(
        dialogStillMountedAtDispatch,
        isFalse,
        reason:
            'RideAssignRequested was dispatched while the AssignmentDialog '
            'route was still mounted — this is the mid-teardown dispatch that '
            'trips the _dependents.isEmpty assertion on device. The dispatch '
            'must be deferred until after the dialog has been popped.',
      );

      // Belt and suspenders: no framework assertion leaked through the pumps.
      final fromPump = tester.takeException();
      expect(
        fromPump,
        isNull,
        reason: 'pump surfaced a framework exception: $fromPump',
      );
      expect(
        caught,
        isEmpty,
        reason: caught.isEmpty
            ? ''
            : 'framework error during dialog teardown: ${caught.first.exception}',
      );

      // The follow-up conflict dialog opened cleanly; the AssignmentDialog is
      // gone.
      expect(find.text('Driver Busy'), findsOneWidget);
      expect(find.textContaining('Assign Ride'), findsNothing);
    },
  );

  testWidgets(
    'assigning a ride that was already taken (409 "Ride already assigned") '
    'shows an info snackbar and reloads the pending list — no "Driver Busy" '
    'conflict dialog, no red error/Retry',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Override the default conflict stub: this time the backend reports the
      // ride was already assigned (stale dispatcher view). The first
      // getPendingRides() (initState) returns the pending ride; after the failed
      // assign the bloc reloads and the ride is gone.
      var pendingReloaded = false;
      when(() => mockRideService.getPendingRides()).thenAnswer((_) async {
        if (pendingReloaded) return <Ride>[];
        return [pendingRide];
      });
      when(
        () => mockRideService.assignDriver(
          any(),
          any(),
          overrideScheduleConflict: any(named: 'overrideScheduleConflict'),
        ),
      ).thenAnswer((_) async {
        pendingReloaded = true;
        throw ApiException('Ride already assigned', statusCode: 409);
      });

      await tester.pumpWidget(buildPanel());
      await _pumpUntilFound(tester, find.text('Assign'));

      await tester.tap(find.text('Assign').first);
      await _pumpUntilFound(tester, find.text('Select Driver'));

      await _pumpUntilFound(tester, find.text('Driver Hans'));
      await tester.ensureVisible(find.text('Driver Hans'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      await tester.tap(find.text('Driver Hans'));
      await _pumpUntilFound(tester, find.textContaining('Assign Ride'));

      expect(find.text('Assign driver'), findsOneWidget);
      await tester.tap(find.text('Assign driver'));

      // The info snackbar surfaces instead of the conflict dialog.
      await _pumpUntilFound(
        tester,
        find.text(
          'This ride was already assigned. The list has been refreshed.',
        ),
      );

      // No "Driver Busy" conflict dialog and no doomed Retry / red error.
      expect(find.text('Driver Busy'), findsNothing);
      expect(find.textContaining('Assign Ride'), findsNothing);

      // The pending list was reloaded after the rejection.
      verify(() => mockRideService.getPendingRides()).called(greaterThan(1));
    },
  );
}

/// Pumps repeatedly until [finder] matches at least one widget, or the attempt
/// budget runs out. RideBloc / UserService deliver results across real async
/// stream/future hops, so a fixed pumpAndSettle() can race ahead of the widget
/// being pushed; this drains the real event loop between pumps.
///
/// Fails fast (throws) when the budget is exhausted instead of returning
/// silently: a silent return let a wrong-text finder slip through and hang the
/// subsequent pumpAndSettle() for the full 10-minute test timeout.
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
  fail(
    'Timed out after $maxTries pumps waiting for: '
    '${finder.describeMatch(Plurality.zero)}',
  );
}
