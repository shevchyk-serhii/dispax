// RideDetailsScreen's "View on map" action must open the IN-APP ride-bound map
// (RideMapScreen) instead of the old behaviour of launching external Google
// Maps. External navigation stays available via the "Navigate" actions.
//
// RideMapScreen mounts a Mapbox platform view, so the test asserts the *push*
// (by route name) via a NavigatorObserver and never pumps a frame afterwards.
//
// Mutation check: revert _viewOnMap to NavigationUtils.navigateToMap and this
// test goes red (nothing is pushed onto the navigator).

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/ride_details_screen.dart';
import 'package:dispax/screens/ride_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

class _FakeRideEvent extends Fake implements RideEvent {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
    registerFallbackValue(_FakeAuthEvent());
  });

  late _MockRideBloc rideBloc;
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    rideBloc = _MockRideBloc();
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();

    when(() => rideBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.state).thenReturn(
      AuthState.authenticated(
        TestFixtures.driver(id: 'driver-1', name: 'Driver Hans'),
      ),
    );
    when(() => authBloc.apiClient).thenReturn(apiClient);
    // The screen calls getDriverProximity (GET) in a post-frame callback for
    // the non-client (driver) view; stub it so the screen renders cleanly.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
  });

  testWidgets(
    '"View on map" on the ride details screen pushes the in-app ride map',
    (tester) async {
      // The detail screen is tall; give the test a phone-sized viewport so the
      // action card's buttons are on screen and tappable.
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: BlocProvider<RideBloc>.value(
              value: rideBloc,
              child: RideDetailsScreen(
                ride: TestFixtures.ride(status: RideStatus.assigned),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('View on map'));

      // Assert the push only — pumping a frame here would build RideMapScreen
      // and with it the Mapbox platform view, which widget tests cannot host.
      expect(observer.pushedRouteNames, contains(RideMapScreen.routeName));

      // Tear the tree down without giving the pushed route a frame to build.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
