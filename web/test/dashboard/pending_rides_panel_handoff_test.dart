// Tests for the dispatcher's hand-off feedback loop on the PendingRidesPanel.
//
// Before the fix, pressing "Hand Off" produced no visible result: on success
// the ride became HandedOff and vanished from both tabs (Pending shows only
// Requested, Assigned showed only Assigned/Confirmed) with no confirmation; on
// failure (e.g. 409 "Cannot transition ... to HandedOff" because the ride was
// already taken) the panel's BlocListener didn't listen for the
// `handingOff -> error` transition, so the error was swallowed. In both cases
// the dispatcher saw nothing and assumed it "didn't work".
//
// These tests drive the real bloc -> panel listener and assert:
//   * a handed-off ride stays visible in the Assigned tab (with its count);
//   * a successful hand-off shows a confirmation snackbar;
//   * a failed hand-off shows an error snackbar, and an already-taken failure
//     reloads the pending list.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
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

  final requestedRide = TestFixtures.ride(
    id: 'ride-1',
    status: RideStatus.requested,
  );
  final handedOffRide = TestFixtures.ride(
    id: 'ride-1',
    status: RideStatus.handedOff,
  );

  setUp(() {
    mockRideService = MockRideService();
    mockScheduleService = MockScheduleService();
    mockApiClient = MockApiClient();

    when(
      () => mockRideService.getPendingRides(),
    ).thenAnswer((_) async => [requestedRide]);
    when(() => mockRideService.dispose()).thenReturn(null);
    when(
      () => mockScheduleService.getScheduleForDate(any()),
    ).thenAnswer((_) async => []);

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

  testWidgets(
    'a handed-off ride is shown in the Assigned tab and counted in its badge',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildPanel());
      await _pumpUntilFound(tester, find.text('Assign'));

      // Seed a loaded state where the only ride is HandedOff.
      rideBloc.emit(RideState.loaded([handedOffRide]));
      await tester.pump();

      // Switch to the Assigned tab.
      await tester.tap(find.text('Assigned'));
      await tester.pumpAndSettle();

      // The handed-off ride's client name is rendered (it did not vanish). The
      // row shows it inside a joined meta line, so match on a substring.
      expect(find.textContaining('Test Client'), findsWidgets);
      // The handed-off status badge is shown on the row.
      expect(find.text('Handed Off'), findsWidgets);
      // The Assigned tab badge counts the handed-off ride (count = 1).
      expect(find.text('1'), findsWidgets);
      // It is read-only: no Reassign action button on the row.
      expect(find.text('Reassign'), findsNothing);
    },
  );

  testWidgets('a successful hand-off shows a confirmation snackbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(
      () => mockRideService.handOffRide(
        'ride-1',
        externalDriverId: any(named: 'externalDriverId'),
        partnerCompanyId: any(named: 'partnerCompanyId'),
      ),
    ).thenAnswer((_) async => handedOffRide);

    await tester.pumpWidget(buildPanel());
    await _pumpUntilFound(tester, find.text('Assign'));

    rideBloc.add(
      const RideHandOffRequested(
        rideId: 'ride-1',
        externalDriverId: 'ext-1',
        partnerCompanyId: 'partner-1',
      ),
    );

    await _pumpUntilFound(
      tester,
      find.text('Ride handed off to the external partner.'),
    );
    expect(
      find.text('Ride handed off to the external partner.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a failed already-taken hand-off shows an error snackbar and reloads '
    'the pending list',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var reloaded = false;
      when(() => mockRideService.getPendingRides()).thenAnswer((_) async {
        if (reloaded) return <Ride>[];
        return [requestedRide];
      });
      when(
        () => mockRideService.handOffRide(
          'ride-1',
          externalDriverId: any(named: 'externalDriverId'),
          partnerCompanyId: any(named: 'partnerCompanyId'),
        ),
      ).thenAnswer((_) async {
        reloaded = true;
        throw ApiException(
          'Cannot transition from Assigned to HandedOff',
          statusCode: 409,
        );
      });

      await tester.pumpWidget(buildPanel());
      await _pumpUntilFound(tester, find.text('Assign'));

      rideBloc.add(
        const RideHandOffRequested(
          rideId: 'ride-1',
          externalDriverId: 'ext-1',
          partnerCompanyId: 'partner-1',
        ),
      );

      await _pumpUntilFound(tester, find.textContaining('Hand-off failed:'));
      expect(find.textContaining('Hand-off failed:'), findsOneWidget);

      // The already-taken failure triggers a pending reload (initial load + the
      // post-failure reload).
      verify(() => mockRideService.getPendingRides()).called(greaterThan(1));
    },
  );
}

/// Pumps repeatedly until [finder] matches, draining real async hops between
/// pumps. Fails fast when the budget is exhausted instead of hanging the
/// subsequent pumpAndSettle for the full test timeout.
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
