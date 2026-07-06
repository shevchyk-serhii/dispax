// Visibility gate for the "Assign to me" self-assign toggle
// (CreateRideDriverSection) inside the shared create-ride form.
//
// The toggle sets the request's driverId to the current user's id, so it must
// only be shown to someone the backend will accept as a driver: a pure driver,
// or a dispatcher who ALSO holds the driver role (multirole). A pure dispatcher
// must not see it — the backend rejects assigning a ride to a non-driver
// (BusinessRuleViolation "driver_role"), so the toggle would produce a failing
// request. The gate therefore keys on Person.canDrive (the role SET), not the
// single primary role.
//
// Mutation discriminator: the "multirole dispatcher SEES the toggle" case flips
// red if the gate is reverted to `role == PersonRole.driver`. The other two
// cases pass under both the old and new gate — they are regression guards.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/create_ride_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _FakeRideEvent extends Fake implements RideEvent {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

// A dispatcher who also holds the driver role — the multirole case that must
// now see the toggle.
Person _dispatcherDriver() => Person(
  id: 'disp-driver-1',
  name: 'Disp Driver',
  email: 'disp.driver@example.com',
  role: PersonRole.dispatcher,
  companyId: 'company-1',
  phone: '+491234567890',
  roles: {PersonRole.dispatcher, PersonRole.driver},
);

// A plain dispatcher with no driver role — must NOT see the toggle.
Person _pureDispatcher() => Person(
  id: 'disp-1',
  name: 'Dispatcher Anna',
  email: 'disp@example.com',
  role: PersonRole.dispatcher,
  companyId: 'company-1',
  phone: '+491234567890',
  roles: {PersonRole.dispatcher},
);

// A plain driver — the original audience; must still see the toggle.
Person _driver() => Person(
  id: 'driver-1',
  name: 'Hans Weber',
  email: 'hans@example.com',
  role: PersonRole.driver,
  companyId: 'company-1',
  phone: '+491111111111',
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
    registerFallbackValue(_FakeAuthEvent());
  });

  late _MockRideBloc rideBloc;
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;
  late CreateRideFormBloc formBloc;

  setUp(() {
    rideBloc = _MockRideBloc();
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    formBloc = CreateRideFormBloc();

    when(() => rideBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.add(any())).thenAnswer((_) {});
    when(() => rideBloc.state).thenReturn(const RideState());
    // The form body's basic-info/location sections read authBloc.apiClient on
    // init and issue GETs (client search); stub both so the body renders.
    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));
  });

  tearDown(() {
    formBloc.close();
  });

  Widget buildSubject(Person user) {
    when(() => authBloc.state).thenReturn(AuthState.authenticated(user));
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: CreateRideScreen(
          rideBloc: rideBloc,
          formBloc: formBloc,
          onCreated: () {},
        ),
      ),
    );
  }

  // Assert after a single pump() only — the gate is computed synchronously in
  // build(); pumpAndSettle() would hang on the location section's debounce
  // timers.

  testWidgets(
    'multirole dispatcher (roles={dispatcher,driver}) SEES the toggle '
    '(mutation discriminator)',
    (tester) async {
      await tester.pumpWidget(buildSubject(_dispatcherDriver()));
      await tester.pump();

      expect(find.text('Assign to me'), findsOneWidget);
    },
  );

  testWidgets('pure dispatcher (roles={dispatcher}) does NOT see the toggle', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(_pureDispatcher()));
    await tester.pump();

    expect(find.text('Assign to me'), findsNothing);
  });

  testWidgets('plain driver still sees the toggle (regression guard)', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(_driver()));
    await tester.pump();

    expect(find.text('Assign to me'), findsOneWidget);
  });
}
