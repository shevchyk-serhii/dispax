// Phase 2 (error-UX), Bug B: when the pending-rides load fails, the dispatcher
// panel must show a friendly error with a Retry button — NOT the green "No
// rides" empty state (which is what the screenshot showed on a timeout, hiding
// the failure and offering no recovery).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
import 'package:dispax/dashboard/dispatcher/widgets/pending_rides_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/widgets/error_widget.dart';

import '../helpers/mocks.dart';

void main() {
  late MockRideService mockRideService;
  late MockScheduleService mockScheduleService;
  late MockApiClient mockApiClient;
  late RideBloc rideBloc;
  late ScheduleBloc scheduleBloc;
  late AuthBloc authBloc;

  ApiException pendingTimeout() => ApiException(
    'Failed to perform GET request to '
    'https://dispax-o2trzxjbva-ew.a.run.app/api/rides/pending: '
    'TimeoutException after 0:00:15.000000: Future not completed',
    cause: TimeoutException('t'),
  );

  setUp(() {
    mockRideService = MockRideService();
    mockScheduleService = MockScheduleService();
    mockApiClient = MockApiClient();

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

  Widget buildPanel() => MultiBlocProvider(
    providers: [
      BlocProvider<RideBloc>.value(value: rideBloc),
      BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: PendingRidesPanel()),
    ),
  );

  Future<AppLocalizations> loadEn() =>
      AppLocalizations.delegate.load(const Locale('en'));

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 60; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    fail('Timed out waiting for ${finder.describeMatch(Plurality.zero)}');
  }

  testWidgets('load timeout shows a friendly error + Retry, not "No rides"', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final l10n = await loadEn();
    when(() => mockRideService.getPendingRides()).thenThrow(pendingTimeout());

    await tester.pumpWidget(buildPanel());
    rideBloc.add(const RideLoadPendingRequested());

    await pumpUntil(tester, find.byType(ErrorDisplayWidget));

    // The friendly, localized timeout message is shown...
    expect(find.text(l10n.errorTimeout), findsOneWidget);
    // ...with a Retry button...
    expect(find.widgetWithText(ElevatedButton, l10n.retry), findsOneWidget);
    // ...and crucially NOT the false "No rides" empty state.
    expect(find.text(l10n.noPendingRides), findsNothing);
    expect(find.text(l10n.noAssignedRides), findsNothing);
    // No raw exception text leaks into the UI.
    expect(find.textContaining('ApiException'), findsNothing);
    expect(find.textContaining('TimeoutException'), findsNothing);
    expect(find.textContaining('/api/'), findsNothing);
  });

  testWidgets('tapping Retry re-requests the pending rides', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final l10n = await loadEn();
    when(() => mockRideService.getPendingRides()).thenThrow(pendingTimeout());

    await tester.pumpWidget(buildPanel());
    rideBloc.add(const RideLoadPendingRequested());
    await pumpUntil(tester, find.byType(ErrorDisplayWidget));

    await tester.tap(find.widgetWithText(ElevatedButton, l10n.retry));
    await tester.pump();

    // Initial load + the retry = at least two calls.
    verify(() => mockRideService.getPendingRides()).called(greaterThan(1));
  });
}
