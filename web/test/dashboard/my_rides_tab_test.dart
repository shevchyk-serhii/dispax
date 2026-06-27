import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/blocs/saved_places/saved_places_bloc.dart';
import 'package:dispax/blocs/saved_places/saved_places_event.dart';
import 'package:dispax/blocs/saved_places/saved_places_state.dart';
import 'package:dispax/dashboard/client/client_dashboard.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/client_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

// ─── Fakes for registerFallbackValue ─────────────────────────────────────────

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _FakeRideEvent extends Fake implements RideEvent {}

class _FakeSavedPlacesEvent extends Fake implements SavedPlacesEvent {}

// ─── Mock BLoCs ───────────────────────────────────────────────────────────────

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockSavedPlacesBloc extends MockBloc<SavedPlacesEvent, SavedPlacesState>
    implements SavedPlacesBloc {}

class _MockApiClient extends Mock implements ApiClient {}

// ─── NavigatorObserver to capture pushes ─────────────────────────────────────

class _TestNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushedRoute = route;
  }
}

// ─── Fixtures ─────────────────────────────────────────────────────────────────

Person _client() => Person(
  id: 'client-42',
  name: 'Test Client',
  email: 'client@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
  phone: '+4912345678',
);

Ride _trackableRide(String id, RideStatus status) => TestFixtures.ride(
  id: id,
  clientId: 'client-42',
  status: status,
  driverName: 'Driver Hans',
  driverId: 'driver-1',
);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(_FakeRideEvent());
    registerFallbackValue(_FakeSavedPlacesEvent());
  });

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;
  late _MockSavedPlacesBloc savedPlacesBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    savedPlacesBloc = _MockSavedPlacesBloc();
    apiClient = _MockApiClient();

    when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(() => rideBloc.add(any())).thenAnswer((_) {});
    when(() => savedPlacesBloc.state).thenReturn(SavedPlacesState.initial());
    when(() => savedPlacesBloc.add(any())).thenAnswer((_) {});
  });

  Widget buildTabWithRides(List<Ride> rides) {
    when(() => rideBloc.state).thenReturn(RideState.loaded(rides));

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RideBloc>.value(value: rideBloc),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: const MyRidesTab()),
      ),
    );
  }

  // ─── Card rendering ──────────────────────────────────────────────────────────

  // Mutation check performed: temporarily changed `isTrackable` to always
  // return `false`, which made the "Track driver" buttons disappear so the
  // "Track driver" finder returned zero matches — tests below went red.
  // Restored the correct implementation.
  group('MyRidesTab — card rendering', () {
    testWidgets('renders two cards when two trackable rides exist', (
      tester,
    ) async {
      final rides = [
        _trackableRide('ride-A', RideStatus.assigned),
        _trackableRide('ride-B', RideStatus.inProgress),
      ];

      await tester.pumpWidget(buildTabWithRides(rides));
      await tester.pump();

      // Each ride produces a Card with its route as the title.
      // Default fixture: "Pickup St 1 → Dropoff St 2"
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('"Track driver" button is visible for each trackable ride', (
      tester,
    ) async {
      final rides = [
        _trackableRide('ride-A', RideStatus.assigned),
        _trackableRide('ride-B', RideStatus.confirmed),
      ];

      await tester.pumpWidget(buildTabWithRides(rides));
      await tester.pump();

      // Both cards must show the "Track driver" button.
      expect(find.text('Track driver'), findsNWidgets(2));
    });

    testWidgets('requested ride does NOT show "Track driver" button', (
      tester,
    ) async {
      final rides = [
        TestFixtures.ride(id: 'ride-req', clientId: 'client-42'),
        // Default status is requested
      ];

      await tester.pumpWidget(buildTabWithRides(rides));
      await tester.pump();

      expect(find.text('Track driver'), findsNothing);
    });
  });

  // ─── Navigation on "Track driver" tap ────────────────────────────────────────

  group('MyRidesTab — Track driver navigation', () {
    testWidgets(
      '"Track driver" tap pushes ClientMapScreen with the correct rideId',
      (tester) async {
        const targetRideId = 'ride-XYZ';
        final rides = [_trackableRide(targetRideId, RideStatus.assigned)];

        when(() => rideBloc.state).thenReturn(RideState.loaded(rides));

        final observer = _TestNavigatorObserver();

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<RideBloc>.value(value: rideBloc),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              navigatorObservers: [observer],
              home: Scaffold(body: const MyRidesTab()),
            ),
          ),
        );
        await tester.pump();

        // Tap the "Track driver" button.
        await tester.tap(find.text('Track driver'));
        await tester.pump();

        // A new route should have been pushed.
        expect(observer.lastPushedRoute, isNotNull);

        // The pushed route must be a MaterialPageRoute whose widget is a
        // ClientMapScreen with the expected rideId.
        final pushedRoute = observer.lastPushedRoute;
        expect(pushedRoute, isA<MaterialPageRoute>());
        final built = (pushedRoute as MaterialPageRoute).builder(
          tester.element(find.byType(Scaffold).first),
        );
        // The route re-exposes RideBloc via BlocProvider so ClientMapScreen can
        // read it after navigation (root Navigator is above the app's provider).
        expect(built, isA<BlocProvider<RideBloc>>());
        final screen = (built as BlocProvider<RideBloc>).child;
        expect(screen, isA<ClientMapScreen>());
        expect((screen as ClientMapScreen).rideId, targetRideId);
      },
    );

    testWidgets(
      '"Track driver" on second ride pushes ClientMapScreen with the second rideId',
      (tester) async {
        const firstRideId = 'ride-FIRST';
        const secondRideId = 'ride-SECOND';
        final rides = [
          _trackableRide(firstRideId, RideStatus.assigned),
          _trackableRide(secondRideId, RideStatus.inProgress),
        ];

        when(() => rideBloc.state).thenReturn(RideState.loaded(rides));

        final observer = _TestNavigatorObserver();

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<RideBloc>.value(value: rideBloc),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              navigatorObservers: [observer],
              home: Scaffold(body: const MyRidesTab()),
            ),
          ),
        );
        await tester.pump();

        // Tap the second "Track driver" button.
        final trackButtons = find.text('Track driver');
        expect(trackButtons, findsNWidgets(2));
        await tester.tap(trackButtons.at(1));
        await tester.pump();

        final pushedRoute = observer.lastPushedRoute as MaterialPageRoute;
        final built = pushedRoute.builder(
          tester.element(find.byType(Scaffold).first),
        );
        final screen = (built as BlocProvider<RideBloc>).child;
        expect((screen as ClientMapScreen).rideId, secondRideId);
      },
    );
  });
}
