// The backend rejects reassigning a ride whose pickup time has already passed
// (past_ride business rule), so the driver board must hide its reassign
// affordances for past rides: the per-ride swap icon and the bulk-reassign
// icon (which must also not offer past rides inside the dialog).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
import 'package:dispax/dashboard/dispatcher/widgets/driver_schedule_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';

import '../../helpers/mocks.dart';
import '../../helpers/test_fixtures.dart';

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

  Ride assignedRide({required String id, required DateTime pickup}) =>
      TestFixtures.ride(
        id: id,
        status: RideStatus.assigned,
        pickupDateTime: pickup,
        driverId: 'driver-1',
        driverName: 'Anna',
      );

  Future<void> setUpWithRides(List<Ride> rides) async {
    mockRideService = MockRideService();
    mockScheduleService = MockScheduleService();
    mockApiClient = MockApiClient();

    when(() => mockRideService.getPendingRides()).thenAnswer((_) async => []);
    when(
      () => mockRideService.getRidesForUser(any()),
    ).thenAnswer((_) async => rides);
    when(() => mockRideService.dispose()).thenReturn(null);
    when(() => mockScheduleService.getScheduleForDate(any())).thenAnswer(
      (_) async => [
        TestFixtures.scheduleDay(id: 'sd-1', driverId: 'driver-1', date: today),
      ],
    );
    when(
      () => mockApiClient.get(any()),
    ).thenAnswer((_) async => http.Response('{}', 200));

    rideBloc = RideBloc(rideService: mockRideService);
    scheduleBloc = ScheduleBloc(scheduleService: mockScheduleService);
    authBloc = AuthBloc(apiClient: mockApiClient);
  }

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
      home: Scaffold(
        body: DriverSchedulePanel(selectedDate: today, onDateChanged: (_) {}),
      ),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  Future<void> pumpWithRides(WidgetTester tester, List<Ride> rides) async {
    await setUpWithRides(rides);
    tester.view.physicalSize = const Size(1600, 2400);
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
  }

  testWidgets('driver with only a past assigned ride shows no reassign icons', (
    tester,
  ) async {
    await pumpWithRides(tester, [
      assignedRide(
        id: 'past-1',
        pickup: today.subtract(const Duration(hours: 3)),
      ),
    ]);

    expect(
      find.byIcon(Icons.swap_horiz),
      findsNothing,
      reason:
          'A past ride cannot be reassigned (backend past_ride guard) — '
          'neither the per-ride swap icon nor the bulk-reassign icon may show.',
    );
  });

  testWidgets('driver with a future assigned ride keeps the reassign icons', (
    tester,
  ) async {
    await pumpWithRides(tester, [
      assignedRide(id: 'future-1', pickup: today.add(const Duration(hours: 3))),
    ]);

    expect(find.byIcon(Icons.swap_horiz), findsWidgets);
  });
}
