// Regression test for the reported bug: the dispatcher creates a ride, the
// backend succeeds (201), but the "Create Ride" button stays stuck on
// "Creating Ride..." forever.
//
// Root cause: CreateRideScreen holds two independent blocs. On success the
// RideBloc emits RideStateStatus.created, but the success branch of the
// RideBloc listener never reset the CreateRideFormBloc status from
// `submitting`. Because the dispatcher/driver dashboards reuse a single
// CreateRideFormBloc instance for the whole dashboard lifetime, the form stayed
// in `submitting` and the button never re-enabled.
//
// Fix: on RideStateStatus.created the listener now dispatches FormCleared(),
// mirroring the client booking screen. This test mounts the real
// CreateRideScreen (which routes through that listener) with a real
// CreateRideFormBloc in `submitting` and a mocked RideBloc that emits
// `created`, then asserts the form leaves `submitting`.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';
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

Person _dispatcher() => Person(
  id: 'disp-1',
  name: 'Dispatcher Anna',
  email: 'disp@example.com',
  role: PersonRole.dispatcher,
  companyId: 'company-1',
  phone: '+491234567890',
  roles: {PersonRole.dispatcher},
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
    when(
      () => authBloc.state,
    ).thenReturn(AuthState.authenticated(_dispatcher()));
    // The form body's basic-info section reads authBloc.apiClient on init and
    // issues GETs (e.g. client search). Stub both so the body renders.
    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));
  });

  tearDown(() {
    formBloc.close();
  });

  Widget buildSubject() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: CreateRideScreen(
        rideBloc: rideBloc,
        formBloc: formBloc,
        // Keep the test independent of navigation — onCreated is a no-op so the
        // assertion is purely about the form status being reset.
        onCreated: () {},
      ),
    ),
  );

  testWidgets(
    'on RideStateStatus.created the form leaves `submitting` so the button '
    're-enables (regression: stuck on "Creating Ride...")',
    (tester) async {
      // The form is mid-submit: the button shows "Creating Ride...".
      formBloc.emit(
        formBloc.state.copyWith(status: CreateRideFormStatus.submitting),
      );
      expect(
        formBloc.state.status,
        CreateRideFormStatus.submitting,
        reason: 'precondition: form is submitting before the success arrives',
      );

      // The backend succeeded: RideBloc transitions loading → created while the
      // screen is mounted, so the listener fires on the status change.
      whenListen(
        rideBloc,
        Stream<RideState>.fromIterable([
          RideState(status: RideStateStatus.created, rides: const []),
        ]),
        initialState: RideState.loading(),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // The form must no longer be submitting — FormCleared() resets it to
      // initial, so the "Create Ride" button re-enables.
      expect(
        formBloc.state.status,
        isNot(CreateRideFormStatus.submitting),
        reason:
            'after a successful create the form must leave submitting, '
            'otherwise the button stays stuck on "Creating Ride..."',
      );
      expect(formBloc.state.status, CreateRideFormStatus.initial);
    },
  );

  testWidgets('successful create resets the form fields to initial values', (
    tester,
  ) async {
    // Fill the form, then mark it submitting (as a real submit would).
    formBloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
    formBloc.add(const FromAddressChanged('Marienplatz 1'));
    formBloc.add(const ToAddressChanged('Flughafen München'));
    await tester.pump();
    formBloc.emit(
      formBloc.state.copyWith(status: CreateRideFormStatus.submitting),
    );

    whenListen(
      rideBloc,
      Stream<RideState>.fromIterable([
        RideState(status: RideStateStatus.created, rides: const []),
      ]),
      initialState: RideState.loading(),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final s = formBloc.state;
    expect(s.fromAddress, '');
    expect(s.toAddress, '');
    expect(s.selectedClientId, isNull);
    expect(s.isModified, isFalse);
  });
}
