// Phase 2 (error-UX), Bug C: the booking screen listens to the SHARED RideBloc.
// A background load failure elsewhere (e.g. the dispatcher's pending-rides
// timeout) flips the shared bloc to `error`. Without a guard, this screen showed
// its "couldn't book your ride" banner for an error it never caused. The fix:
// only react to an `error` while THIS screen's own submit is in flight (the
// CreateRideFormBloc is `submitting`).

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
import 'package:dispax/dashboard/client/client_book_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _FakeRideEvent extends Fake implements RideEvent {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _client() => Person(
  id: 'client-self-1',
  name: 'Bruno Aldi',
  email: 'bruno@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
  phone: '+491234567890',
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeRideEvent()));

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
    when(() => rideBloc.add(any())).thenAnswer((_) {});
  });

  Widget host(CreateRideFormBloc formBloc) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locale: const Locale('en'),
    home: Scaffold(
      body: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: ClientBookScreen(formBloc: formBloc, rideBloc: rideBloc),
      ),
    ),
  );

  // A background pending-load timeout on the shared bloc — NOT this screen's
  // doing. The form is left untouched (never `submitting`).
  testWidgets('does NOT show a booking-error banner for a foreign load error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final formBloc = CreateRideFormBloc();
    addTearDown(formBloc.close);

    // Shared bloc goes loading -> error while the form sits idle (not submitting).
    whenListen(
      rideBloc,
      Stream<RideState>.fromIterable([
        RideState.loading(),
        RideState.error(
          'Failed to load pending rides: timeout',
          cause: ApiException('x', statusCode: 503),
        ),
      ]),
      initialState: RideState.loaded(const []),
    );

    await tester.pumpWidget(host(formBloc));
    await tester.pump();
    await tester.pump();

    expect(formBloc.state.status, isNot(CreateRideFormStatus.submitting));
    // No error banner at all for a foreign error: without the guard the screen
    // would surface friendlyError(503) == errorServer in a SnackBar.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(l10n.errorServer), findsNothing);
    expect(find.text(l10n.failedToCreateRide), findsNothing);
    expect(find.textContaining('Failed to load pending rides'), findsNothing);
  });

  // When THIS screen's submit is in flight (form submitting) and the shared bloc
  // errors, the booking-error banner SHOULD appear.
  testWidgets('DOES show a friendly banner when our own submit fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    when(
      () => apiClient.post(any(), any()),
    ).thenAnswer((_) async => http.Response('{}', 200));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final formBloc = CreateRideFormBloc();
    addTearDown(formBloc.close);
    // Put the form into `submitting` — this is "our submit is in flight".
    formBloc.add(const ClientSelected(clientId: 'c-1', clientName: 'A'));
    formBloc.add(const FromAddressChanged('Main 1'));
    formBloc.add(const ToAddressChanged('Hotel'));
    formBloc.add(FormSubmitted());

    whenListen(
      rideBloc,
      Stream<RideState>.fromIterable([
        RideState.error('boom', cause: ApiException('x', statusCode: 500)),
      ]),
      initialState: RideState.loaded(const []),
    );

    await tester.pumpWidget(host(formBloc));
    await tester.pump();
    await tester.pump();

    // The server error maps to a friendly server message (not generic-empty,
    // not raw). Its presence proves the banner fired for OUR submit.
    expect(find.text(l10n.errorServer), findsOneWidget);
  });
}
