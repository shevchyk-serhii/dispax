// Widget tests for the RideDetailsScreen AppBar title.
//
// The title used to render the full ride UUID ("Ride #e4e4e4e4-...") which is
// unreadable and carries no information for a human. It now shows:
//   - dispatcher/driver view: "Ride · <client name>"
//   - client view:            "My Ride · <dd.MM HH:mm pickup time>"
// The raw ride id must not appear in the title in either view.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/ride_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

// ─── Local fakes / mocks ─────────────────────────────────────────────────────

class _FakeRideEvent extends Fake implements RideEvent {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const _rideId = 'e4e4e4e4-e4e4-e4e4-e4e4-e4e4e4e4e4e4';

Ride _ride() {
  return Ride(
    id: _rideId,
    clientId: 'client-1',
    creatorId: 'creator-1',
    companyId: 'company-1',
    pickupDateTime: DateTime(2026, 3, 15, 10, 30),
    from: const Location(
      address: 'Pickup St 1',
      latitude: 48.1,
      longitude: 11.5,
    ),
    to: const Location(
      address: 'Dropoff St 2',
      latitude: 48.2,
      longitude: 11.6,
    ),
    status: RideStatus.requested,
    clientName: 'Max Mustermann',
  );
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
    // The screen calls getDriverProximity in a post-frame callback; stub it.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
  });

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildSubject(Ride ride, {bool isClientView = false}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: BlocProvider<RideBloc>.value(
        value: rideBloc,
        child: RideDetailsScreen(ride: ride, isClientView: isClientView),
      ),
    ),
  );

  Text appBarTitle(WidgetTester tester) => tester.widget<Text>(
    find.descendant(of: find.byType(AppBar), matching: find.byType(Text)),
  );

  testWidgets('dispatcher/driver title shows client name, not the ride id', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(buildSubject(_ride()));
    await tester.pump(); // settle post-frame callback

    expect(
      appBarTitle(tester).data,
      'Ride · Max Mustermann',
      reason: 'the AppBar title must identify the ride by client name',
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.textContaining(_rideId.substring(0, 8)),
      ),
      findsNothing,
      reason: 'the raw UUID must not leak into the AppBar title',
    );
  });

  testWidgets('client view title shows pickup date/time, not the ride id', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(buildSubject(_ride(), isClientView: true));
    await tester.pump();

    expect(
      appBarTitle(tester).data,
      'My Ride · 15.03 10:30',
      reason: 'the client AppBar title must show the pickup date and time',
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.textContaining(_rideId.substring(0, 8)),
      ),
      findsNothing,
      reason: 'the raw UUID must not leak into the AppBar title',
    );
  });
}
