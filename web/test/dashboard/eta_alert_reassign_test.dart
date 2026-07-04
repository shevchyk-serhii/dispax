// Regression: the "Reassign" button on the dispatcher's ETA at-risk alert was
// dead — it invoked an optional callback (onReassignFromEtaAlert) that no
// caller ever wired, so the tap did nothing. It must open the same driver
// selection sheet as the Assigned tab's Reassign action, and it must respect
// the past_ride guard: a ride whose pickup time already passed cannot be
// reassigned (backend rejects it), so its alert must not offer the button.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
import 'package:dispax/dashboard/dispatcher/widgets/eta_alert_card.dart';
import 'package:dispax/dashboard/dispatcher/widgets/pending_rides_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
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

  final assignedFuture = TestFixtures.ride(
    id: 'assigned-future',
    status: RideStatus.assigned,
    pickupDateTime: DateTime.now().add(const Duration(hours: 2)),
    from: TestFixtures.location(address: 'Marienplatz'),
    driverId: 'driver-1',
    driverName: 'Anna',
  );
  final assignedPast = TestFixtures.ride(
    id: 'assigned-past',
    status: RideStatus.assigned,
    pickupDateTime: DateTime.now().subtract(const Duration(hours: 2)),
    from: TestFixtures.location(address: 'Ostbahnhof'),
    driverId: 'driver-1',
    driverName: 'Anna',
  );

  EtaAtRiskInfo alertFor(String rideId) => EtaAtRiskInfo(
    rideId: rideId,
    driverName: 'Anna',
    etaMinutes: 25,
    pickupInMinutes: 10,
    slackMinutes: -15,
  );

  setUp(() {
    mockRideService = MockRideService();
    mockScheduleService = MockScheduleService();
    mockApiClient = MockApiClient();

    when(() => mockRideService.getPendingRides()).thenAnswer((_) async => []);
    when(
      () => mockRideService.getRidesForUser(any()),
    ).thenAnswer((_) async => [assignedFuture, assignedPast]);
    when(() => mockRideService.dispose()).thenReturn(null);
    when(
      () => mockScheduleService.getScheduleForDate(any()),
    ).thenAnswer((_) async => []);
    when(
      () => mockApiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));

    rideBloc = RideBloc(rideService: mockRideService);
    scheduleBloc = ScheduleBloc(scheduleService: mockScheduleService);
    authBloc = AuthBloc(apiClient: mockApiClient);
  });

  tearDown(() {
    rideBloc.close();
    scheduleBloc.close();
    authBloc.close();
  });

  setUpAll(() {
    registerFallbackValue(
      Person(
        id: 'fallback',
        name: 'x',
        email: 'x@x.de',
        role: PersonRole.dispatcher,
      ),
    );
  });

  Widget buildPanel(List<EtaAtRiskInfo> alerts) => MultiBlocProvider(
    providers: [
      BlocProvider<RideBloc>.value(value: rideBloc),
      BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PendingRidesPanel(etaAlerts: alerts)),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  Future<void> loadRides(WidgetTester tester) async {
    rideBloc.add(
      RideLoadRequested(
        user: Person(
          id: 'disp-1',
          name: 'Disp',
          email: 'd@x.de',
          role: PersonRole.dispatcher,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('tapping Reassign on an at-risk alert opens the driver '
      'selection sheet in reassign mode', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPanel([alertFor('assigned-future')]));
    await loadRides(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byType(EtaAlertCard), findsOneWidget);
    final reassignButton = find.text(l10n.reassign);
    expect(reassignButton, findsOneWidget);

    await tester.tap(reassignButton);
    await settle(tester);

    // The driver selection sheet opened in reassign mode.
    expect(find.text(l10n.reassignDriver), findsOneWidget);
  });

  testWidgets('an alert for a past-pickup ride shows no Reassign button '
      '(backend past_ride guard)', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPanel([alertFor('assigned-past')]));
    await loadRides(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byType(EtaAlertCard), findsOneWidget);
    expect(find.text(l10n.reassign), findsNothing);
  });
}
