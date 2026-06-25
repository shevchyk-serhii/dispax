// Widget tests for payment method display in the PendingRidesPanel _RideRow.
//
// _RideRow (inside PendingRidesPanel) renders the payment label via a Builder
// that calls PaymentMethod.labelForWire and shows Icons.payments_outlined.
// Two cases: (a) paymentMethod='Cash' -> label 'Cash' visible in the row;
//            (b) paymentMethod=null   -> payment label absent.

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

  setUp(() {
    mockRideService = MockRideService();
    mockScheduleService = MockScheduleService();
    mockApiClient = MockApiClient();

    when(
      () => mockScheduleService.getScheduleForDate(any()),
    ).thenAnswer((_) async => []);
    when(
      () => mockApiClient.get(any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
  });

  tearDown(() {
    rideBloc.close();
    scheduleBloc.close();
    authBloc.close();
  });

  Widget buildPanel(Ride ride) {
    when(
      () => mockRideService.getPendingRides(),
    ).thenAnswer((_) async => [ride]);
    when(() => mockRideService.dispose()).thenReturn(null);

    rideBloc = RideBloc(rideService: mockRideService);
    scheduleBloc = ScheduleBloc(scheduleService: mockScheduleService);
    authBloc = AuthBloc(apiClient: mockApiClient);

    return MultiBlocProvider(
      providers: [
        BlocProvider<RideBloc>.value(value: rideBloc),
        BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: PendingRidesPanel()),
      ),
    );
  }

  // Pumps the panel until the ride row appears (the list loads asynchronously).
  Future<void> pumpUntilRideRowVisible(
    WidgetTester tester,
    Finder finder,
  ) async {
    for (var i = 0; i < 60; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    fail('Timed out waiting for ${finder.describeMatch(Plurality.zero)}');
  }

  testWidgets(
    'PendingRidesPanel _RideRow shows "Cash" label when paymentMethod is Cash',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ride = TestFixtures.ride(
        id: 'ride-cash',
        status: RideStatus.requested,
        paymentMethod: 'Cash',
      );
      await tester.pumpWidget(buildPanel(ride));
      await pumpUntilRideRowVisible(tester, find.text('Cash'));

      expect(
        find.text('Cash'),
        findsOneWidget,
        reason:
            'a ride with paymentMethod=Cash must show the label "Cash" in the panel row',
      );
    },
  );

  testWidgets(
    'PendingRidesPanel _RideRow does not show a payment label when paymentMethod is null',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ride = TestFixtures.ride(
        id: 'ride-no-pay',
        status: RideStatus.requested,
        paymentMethod: null,
      );
      await tester.pumpWidget(buildPanel(ride));
      // Wait for the row to load (ride address is a reliable marker).
      await pumpUntilRideRowVisible(tester, find.text('Pickup St 1'));

      expect(find.text('Cash'), findsNothing);
      expect(find.text('Invoice'), findsNothing);
      expect(find.text('Credit Card'), findsNothing);
      expect(find.text('Payment'), findsNothing);
    },
  );
}
