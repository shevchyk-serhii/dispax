// Regressions for the client "Book a ride" screen:
//
//  Bug A: tapping "Scheduled" while in ASAP mode did not open the date/time
//  picker. The handler dispatched ScheduleModeToggled(true) but then guarded
//  the picker with `if (isScheduled)` — the PRE-toggle value — so on the
//  ASAP -> Scheduled switch (isScheduled == false) the picker never opened.
//
//  Bug B: the "Confirm booking" button stayed enabled while a submission was
//  in flight (onPressed only checked isValid, not status == submitting), so a
//  double-tap could create the ride twice.

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

class _MockFormBloc extends MockBloc<CreateRideFormEvent, CreateRideFormState>
    implements CreateRideFormBloc {}

Person _client() => Person(
  id: 'client-self-1',
  name: 'Bruno Aldi',
  email: 'bruno@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
  phone: '+491234567890',
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
  });

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
    when(
      () => apiClient.post(any(), any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
    when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
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

  testWidgets('tapping "Scheduled" from ASAP opens the date picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final formBloc = CreateRideFormBloc();
    addTearDown(formBloc.close);
    // The form defaults to Scheduled; switch to ASAP to set up the
    // ASAP -> Scheduled transition this bug is about.
    formBloc.add(const ScheduleModeToggled(scheduled: false));

    await tester.pumpWidget(host(formBloc));
    await tester.pump();

    expect(formBloc.state.isScheduled, isFalse);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.scheduled));
    await tester.pumpAndSettle();

    // The picker must be on screen after the ASAP -> Scheduled switch.
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('Confirm button is disabled while a submission is in flight', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final formBloc = _MockFormBloc();
    // A valid form that is currently submitting: the button must be disabled
    // even though isValid is true.
    final submitting = CreateRideFormState.initial().copyWith(
      selectedClientId: _client().id,
      clientName: _client().name,
      fromAddress: 'Maximilianstrasse 10',
      toAddress: 'Marienplatz 1',
      status: CreateRideFormStatus.submitting,
    );
    when(() => formBloc.state).thenReturn(submitting);

    await tester.pumpWidget(host(formBloc));
    await tester.pump();

    expect(
      submitting.isValid,
      isTrue,
      reason: 'precondition: the form is valid',
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, l10n.confirmBooking),
    );
    expect(
      button.onPressed,
      isNull,
      reason: 'a submitting form must not accept another tap',
    );
  });
}
