// The backend rejects reassigning a ride whose pickup time has already passed
// (past_ride business rule), so the Assigned tab must hide the Reassign button
// for past rides instead of offering an action that can only fail.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
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
    ).thenAnswer((_) async => http.Response('{}', 200));

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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  testWidgets('Assigned tab: past ride has no Reassign button, future ride '
      'keeps it', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPanel());
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

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.assignedTab));
    await settle(tester);

    // Both rides are listed…
    expect(find.text('Marienplatz'), findsOneWidget);
    expect(find.text('Ostbahnhof'), findsOneWidget);

    // …but only the future ride offers Reassign.
    expect(
      find.text(l10n.reassign),
      findsOneWidget,
      reason:
          'Exactly one Reassign button expected: the past ride must not '
          'offer reassignment (backend past_ride guard).',
    );
  });
}
