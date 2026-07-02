// The "view on map" icon on the driver/dispatcher ride card (DriverRideCard →
// DriverRideActionsRow) must open the in-app ride-bound map (RideMapScreen)
// for exactly that ride.
//
// RideMapScreen mounts a Mapbox platform view, so the navigation test asserts
// the *push* (by route name) via a NavigatorObserver and never pumps a frame
// afterwards — the pushed route is torn down before it ever builds.
//
// Mutation checks:
// - remove the map button from DriverRideActionsRow → "invokes onViewMap" and
//   "card shows the icon" go red;
// - stop wiring onViewMap in DriverRideCard → the navigation test goes red.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/ride_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_fixtures.dart';

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
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(
      () => authBloc.state,
    ).thenReturn(AuthState.authenticated(TestFixtures.driver(id: 'driver-1')));
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    NavigatorObserver? observer,
  }) async {
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [if (observer != null) observer],
          home: Scaffold(
            body: Center(child: SizedBox(width: 360, child: child)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('DriverRideActionsRow tap on the map button invokes onViewMap', (
    tester,
  ) async {
    var viewMapTapped = 0;
    await pump(
      tester,
      DriverRideActionsRow(
        ride: TestFixtures.ride(status: RideStatus.inProgress),
        isDark: false,
        onNavigate: () {},
        onViewMap: () => viewMapTapped++,
      ),
    );

    await tester.tap(find.byIcon(Icons.location_on_outlined));
    expect(viewMapTapped, 1);
  });

  testWidgets('the map button hides when onViewMap is not wired', (
    tester,
  ) async {
    await pump(
      tester,
      DriverRideActionsRow(
        ride: TestFixtures.ride(status: RideStatus.inProgress),
        isDark: false,
        onNavigate: () {},
      ),
    );

    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
  });

  testWidgets(
    'tapping the map icon on DriverRideCard pushes the ride-bound map route',
    (tester) async {
      final observer = _RecordingNavigatorObserver();
      await pump(
        tester,
        DriverRideCard(ride: TestFixtures.ride(status: RideStatus.assigned)),
        observer: observer,
      );

      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.location_on_outlined));

      // Assert the push only — pumping a frame here would build RideMapScreen
      // and with it the Mapbox platform view, which widget tests cannot host.
      expect(observer.pushedRouteNames, contains(RideMapScreen.routeName));

      // Tear the tree down without giving the pushed route a frame to build.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
