// Widget test for NavigationUtils.navigateToRideDetails — the entry point the
// driver's Today live/next cards now use to reach the full ride details (where
// the "Share" guest-tracking-link button lives).
//
// Coverage gap this closes: the driver's _LiveRideCard / _NextRideCard had no
// tap into details at all, so the Share button was unreachable from Today. This
// test locks in that tapping a widget which calls navigateToRideDetails pushes
// a RideDetailsScreen onto the navigator.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/navigation_utils.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/ride_details_screen.dart';
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
    // RideDetailsScreen fires getDriverProximity (GET) in a post-frame callback
    // for the driver view; stub it so the pushed screen renders cleanly.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
  });

  testWidgets('navigateToRideDetails pushes RideDetailsScreen', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ride = TestFixtures.ride(
      status: RideStatus.confirmed,
      driverId: 'driver-1',
    );

    // The providers must sit ABOVE MaterialApp's Navigator: navigateToRideDetails
    // pushes a new route, and the pushed RideDetailsScreen reads AuthBloc from
    // context. A provider scoped inside `home` would not be visible to the new
    // route (mirrors how main.dart wires the blocs above the navigator).
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: BlocProvider<RideBloc>.value(
          value: rideBloc,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        NavigationUtils.navigateToRideDetails(context, ride),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(RideDetailsScreen), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(RideDetailsScreen), findsOneWidget);
  });
}
