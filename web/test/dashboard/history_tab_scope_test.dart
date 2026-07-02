// Regression guard: the "My Rides" History tab used to be scoped to the
// current user's own driven rides for EVERY role, including dispatcher. A
// dispatcher who doesn't personally drive would then always see "No
// completed rides yet" even though the company has completed rides driven by
// other drivers (the backend already returns the full company list; the
// over-scoping happened purely client-side). History is now company-wide for
// a dispatcher, while Today/Upcoming stay scoped to the dispatcher's own
// driving work, and a driver's History stays scoped to their own rides.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _FakeRideEvent extends Fake implements RideEvent {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(_FakeRideEvent());
  });

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    when(() => authBloc.apiClient).thenReturn(_MockApiClient());
  });

  tearDown(() {
    authBloc.close();
    rideBloc.close();
  });

  Future<void> pumpScreenAsHistoryTab(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<RideBloc>.value(value: rideBloc),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const TodayRidesScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('History'));
    await tester.pump();
  }

  group('History tab scoping', () {
    testWidgets(
      'dispatcher sees the whole company history, not just their own driven rides',
      (tester) async {
        final dispatcher = TestFixtures.person(
          id: 'dispatcher-1',
          role: PersonRole.dispatcher,
        );
        when(
          () => authBloc.state,
        ).thenReturn(AuthState.authenticated(dispatcher));

        final rides = [
          TestFixtures.ride(
            id: 'other-drivers-ride',
            driverId: 'some-other-driver',
            status: RideStatus.completed,
            pickupDateTime: DateTime(2026, 1, 1),
          ),
        ];
        final state = RideState(status: RideStateStatus.loaded, rides: rides);
        whenListen(rideBloc, Stream<RideState>.empty(), initialState: state);

        await pumpScreenAsHistoryTab(tester);

        expect(find.text('No completed rides yet'), findsNothing);
      },
    );

    testWidgets(
      'dispatcher with no company-wide completed rides still sees the empty state',
      (tester) async {
        final dispatcher = TestFixtures.person(
          id: 'dispatcher-1',
          role: PersonRole.dispatcher,
        );
        when(
          () => authBloc.state,
        ).thenReturn(AuthState.authenticated(dispatcher));

        const state = RideState(status: RideStateStatus.loaded, rides: []);
        whenListen(rideBloc, Stream<RideState>.empty(), initialState: state);

        await pumpScreenAsHistoryTab(tester);

        expect(find.text('No completed rides yet'), findsOneWidget);
      },
    );

    testWidgets(
      "driver's History still only shows rides they personally drove",
      (tester) async {
        final driver = TestFixtures.driver(id: 'driver-1');
        when(() => authBloc.state).thenReturn(AuthState.authenticated(driver));

        final rides = [
          TestFixtures.ride(
            id: 'other-drivers-ride',
            driverId: 'some-other-driver',
            status: RideStatus.completed,
            pickupDateTime: DateTime(2026, 1, 1),
          ),
        ];
        final state = RideState(status: RideStateStatus.loaded, rides: rides);
        whenListen(rideBloc, Stream<RideState>.empty(), initialState: state);

        await pumpScreenAsHistoryTab(tester);

        expect(find.text('No completed rides yet'), findsOneWidget);
      },
    );
  });
}
