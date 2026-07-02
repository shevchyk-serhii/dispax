// Repro: dispatcher reports the All/Today/Airport chips and the search field do
// not filter the list on the Assigned tab.

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

  final today = DateTime.now();

  final assignedToday = TestFixtures.ride(
    id: 'assigned-today',
    status: RideStatus.assigned,
    pickupDateTime: DateTime(today.year, today.month, today.day, 10, 0),
    from: TestFixtures.location(address: 'Marienplatz'),
    driverId: 'driver-1',
    driverName: 'Anna',
  );
  final assignedPast = TestFixtures.ride(
    id: 'assigned-past',
    status: RideStatus.assigned,
    pickupDateTime: DateTime(2020, 1, 1, 10, 0),
    from: TestFixtures.location(address: 'Ostbahnhof'),
    driverId: 'driver-1',
    driverName: 'Anna',
  );
  // No explicit flag: the airport identity is inferred from the address alone,
  // proving the "Airport" chip catches address-only airport rides.
  final assignedAirport = TestFixtures.ride(
    id: 'assigned-airport',
    status: RideStatus.assigned,
    pickupDateTime: DateTime(2020, 6, 1, 10, 0),
    isAirportTransfer: false,
    from: TestFixtures.location(address: 'Flughafen München'),
    driverId: 'driver-1',
    driverName: 'Anna',
  );

  setUp(() {
    mockRideService = MockRideService();
    mockScheduleService = MockScheduleService();
    mockApiClient = MockApiClient();

    // initState fires RideLoadPendingRequested → no pending rides.
    when(
      () => mockRideService.getPendingRides(),
    ).thenAnswer((_) async => []);
    // Seed the shared list with assigned rides via RideLoadRequested.
    when(
      () => mockRideService.getRidesForUser(any()),
    ).thenAnswer((_) async => [assignedToday, assignedPast, assignedAirport]);
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

  testWidgets('Assigned tab: Today chip filters to today only', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPanel());
    // Seed assigned rides into the shared bloc.
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

    // Switch to the Assigned tab.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.assignedTab));
    await settle(tester);

    // All three assigned rides are shown under "All".
    expect(find.text('Marienplatz'), findsOneWidget);
    expect(find.text('Ostbahnhof'), findsOneWidget);
    expect(find.text('Flughafen München'), findsOneWidget);

    // Tap "Today" → only the today ride should remain.
    await tester.tap(find.text(l10n.today));
    await settle(tester);

    expect(find.text('Marienplatz'), findsOneWidget);
    expect(find.text('Ostbahnhof'), findsNothing);
    expect(find.text('Flughafen München'), findsNothing);
  });

  testWidgets('Assigned tab: Airport chip filters to airport transfers', (
    tester,
  ) async {
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

    await tester.tap(find.text(l10n.airport));
    await settle(tester);

    expect(find.text('Flughafen München'), findsOneWidget);
    expect(find.text('Marienplatz'), findsNothing);
    expect(find.text('Ostbahnhof'), findsNothing);
  });
}
