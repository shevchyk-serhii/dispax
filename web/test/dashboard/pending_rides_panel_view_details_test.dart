// Regression: the dispatcher could not reach a ride's details/edit screen from
// the dashboard — tapping a pending card opened the driver-selection sheet, and
// there was no other affordance. The Edit Ride feature existed on
// RideDetailsScreen but was unreachable for the dispatcher. A details (info)
// button on each ride row now opens RideDetailsScreen.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
import 'package:dispax/dashboard/dispatcher/widgets/pending_rides_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/ride_details_screen.dart';

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

    when(
      () => mockRideService.getPendingRides(),
    ).thenAnswer((_) async => [pendingRide]);
    when(() => mockRideService.dispose()).thenReturn(null);
    when(
      () => mockScheduleService.getScheduleForDate(any()),
    ).thenAnswer((_) async => [TestFixtures.scheduleDay(driverId: 'driver-1')]);
    // RideDetailsScreen._loadEta calls GET driver-proximity; stub it empty.
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

  // Providers wrap MaterialApp (as in the real app, where they sit at the root)
  // so a pushed route like RideDetailsScreen can still read AuthBloc.
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

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 60; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    fail('Timed out waiting for ${finder.describeMatch(Plurality.zero)}');
  }

  testWidgets('the details (info) button opens RideDetailsScreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPanel());
    await pumpUntil(tester, find.byIcon(Icons.info_outline));

    // The dispatcher's pending ride row exposes a details affordance.
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    // RideDetailsScreen is not yet on screen.
    expect(find.byType(RideDetailsScreen), findsNothing);

    await tester.tap(find.byIcon(Icons.info_outline));
    await pumpUntil(tester, find.byType(RideDetailsScreen));

    // The details screen (with its Edit Ride affordance) is now reachable.
    expect(find.byType(RideDetailsScreen), findsOneWidget);
  });
}
