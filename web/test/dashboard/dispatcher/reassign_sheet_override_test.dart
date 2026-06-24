// Regression for the dispatcher reassign-override bug:
//
// The driver-schedule reassign sheet (showReassignSheet) computes schedule
// conflicts with ConflictDetector and shows them in red, but the confirmation
// dialog dispatched RideReassignRequested WITHOUT overrideScheduleConflict.
// The backend then rejected with 409 and the dispatcher had to confirm a
// second time. When the target driver has a clashing ride, confirming
// "Reassign" must dispatch with overrideScheduleConflict: true.
//
// The two drag&drop assign paths in the same file share the identical fix
// (overrideScheduleConflict: conflicts.isNotEmpty on RideAssignRequested);
// this exercises the reassign path, which is the cleanest to drive in
// isolation via the top-level showReassignSheet entry point.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
import 'package:dispax/blocs/schedule/schedule_event.dart';
import 'package:dispax/blocs/schedule/schedule_state.dart';
import 'package:dispax/dashboard/dispatcher/widgets/driver_schedule_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';

import '../../helpers/test_fixtures.dart';

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockScheduleBloc extends MockBloc<ScheduleEvent, ScheduleState>
    implements ScheduleBloc {}

class _FakeRideEvent extends Fake implements RideEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
  });

  late _MockRideBloc rideBloc;
  late _MockScheduleBloc scheduleBloc;

  // The ride being reassigned, currently on driver-1.
  final ride = TestFixtures.ride(
    id: 'ride-1',
    driverId: 'driver-1',
    status: RideStatus.assigned,
    pickupDateTime: DateTime(2026, 3, 15, 10, 0),
    clientName: 'BMW AG',
  );

  // A ride already on driver-2 at the same time → reassigning ride-1 to
  // driver-2 produces a schedule conflict.
  final clashingRide = TestFixtures.ride(
    id: 'ride-2',
    driverId: 'driver-2',
    status: RideStatus.assigned,
    pickupDateTime: DateTime(2026, 3, 15, 10, 0),
  );

  setUp(() {
    rideBloc = _MockRideBloc();
    scheduleBloc = _MockScheduleBloc();

    when(
      () => rideBloc.state,
    ).thenReturn(RideState.loaded([ride, clashingRide]));
    when(() => rideBloc.add(any())).thenAnswer((_) {});

    // driver-2 is on shift and is the only other driver to reassign to.
    when(() => scheduleBloc.state).thenReturn(
      ScheduleState.loaded([
        TestFixtures.scheduleDay(id: 'sd-1', driverId: 'driver-1'),
        TestFixtures.scheduleDay(id: 'sd-2', driverId: 'driver-2'),
      ]),
    );
  });

  Widget harness() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<RideBloc>.value(value: rideBloc),
          BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
        ],
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showReassignSheet(context, ride, const {
                  'driver-2': 'Hans Weber',
                }),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('reassigning to a driver with a clashing ride dispatches with '
      'overrideScheduleConflict: true', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());

    // Open the reassign bottom sheet.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The sheet lists the conflicting target driver in red.
    expect(find.text('Hans Weber'), findsOneWidget);
    expect(find.textContaining('time conflict'), findsOneWidget);

    // Pick the driver → confirmation dialog.
    await tester.tap(find.text('Hans Weber'));
    await tester.pumpAndSettle();

    // Confirm the reassignment.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reassign'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => rideBloc.add(captureAny()),
    ).captured.whereType<RideReassignRequested>().toList();

    expect(captured, hasLength(1));
    expect(captured.single.rideId, 'ride-1');
    expect(captured.single.newDriverId, 'driver-2');
    expect(
      captured.single.overrideScheduleConflict,
      isTrue,
      reason:
          'Conflicts were shown to the dispatcher; confirming must override '
          'the backend guard instead of bouncing off a 409.',
    );
  });
}
