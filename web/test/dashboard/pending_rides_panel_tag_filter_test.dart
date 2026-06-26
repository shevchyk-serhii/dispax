// The dispatcher panel exposes a tag-filter row built from the distinct tags of
// the loaded rides; selecting a tag chip narrows the list to rides carrying it.

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

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  late MockRideService mockRideService;
  late MockScheduleService mockScheduleService;
  late MockApiClient mockApiClient;
  late RideBloc rideBloc;
  late ScheduleBloc scheduleBloc;
  late AuthBloc authBloc;

  final urgentRide = TestFixtures.ride(
    id: 'ride-urgent',
    status: RideStatus.requested,
    from: TestFixtures.location(address: 'Marienplatz'),
    tags: const ['Urgent'],
  );
  final cashRide = TestFixtures.ride(
    id: 'ride-cash',
    status: RideStatus.requested,
    from: TestFixtures.location(address: 'Ostbahnhof'),
    tags: const ['Cash'],
  );
  final plainRide = TestFixtures.ride(
    id: 'ride-plain',
    status: RideStatus.requested,
    from: TestFixtures.location(address: 'Sendling'),
  );

  setUp(() {
    mockRideService = MockRideService();
    mockScheduleService = MockScheduleService();
    mockApiClient = MockApiClient();

    when(
      () => mockRideService.getPendingRides(),
    ).thenAnswer((_) async => [urgentRide, cashRide, plainRide]);
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

  testWidgets('selecting a tag chip filters the list to rides with that tag', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPanel());
    await settle(tester);

    // All three pending rides are shown.
    expect(find.text('Marienplatz'), findsOneWidget);
    expect(find.text('Ostbahnhof'), findsOneWidget);
    expect(find.text('Sendling'), findsOneWidget);

    // The tag-filter row exposes the distinct tags. Tap "Urgent".
    expect(find.text('Urgent'), findsWidgets);
    await tester.tap(find.text('Urgent').first);
    await settle(tester);

    // Only the Urgent ride remains.
    expect(find.text('Marienplatz'), findsOneWidget);
    expect(find.text('Ostbahnhof'), findsNothing);
    expect(find.text('Sendling'), findsNothing);

    // Re-tapping clears the filter — all rides return.
    await tester.tap(find.text('Urgent').first);
    await settle(tester);
    expect(find.text('Ostbahnhof'), findsOneWidget);
    expect(find.text('Sendling'), findsOneWidget);
  });
}
