import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/blocs/saved_places/saved_places_bloc.dart';
import 'package:dispax/blocs/saved_places/saved_places_event.dart';
import 'package:dispax/blocs/saved_places/saved_places_state.dart';
import 'package:dispax/dashboard/client/client_book_screen.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/client_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

// Regression for the client "Book a ride" screen: the Confirm booking button
// was permanently disabled for a client booking for themselves, because
// CreateRideFormState.isValid requires selectedClientId and ClientBookScreen
// never preselected the logged-in user as the client.
//
// The fix is split across two checks:
//   1. The screen must preselect the current user as the client on mount
//      (widget test below).
//   2. With the client preselected, isValid becomes true once addresses are
//      entered, so onPressed (`state.isValid ? ... : null`) is non-null
//      (bloc-level test below — deterministic, no widget timing).

class _FakeRideEvent extends Fake implements RideEvent {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockApiClient extends Mock implements ApiClient {}

class _MockSavedPlacesBloc extends MockBloc<SavedPlacesEvent, SavedPlacesState>
    implements SavedPlacesBloc {}

ClientAddress _savedPlace(String label, String address) => ClientAddress(
  id: 'addr-$label',
  clientId: 'client-self-1',
  label: label,
  address: address,
  useCount: 1,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

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

  group('ClientBookScreen preselects the client', () {
    late _MockAuthBloc authBloc;
    late _MockRideBloc rideBloc;
    late _MockApiClient apiClient;
    late CreateRideFormBloc formBloc;

    setUp(() {
      authBloc = _MockAuthBloc();
      rideBloc = _MockRideBloc();
      apiClient = _MockApiClient();
      formBloc = CreateRideFormBloc();

      when(() => authBloc.apiClient).thenReturn(apiClient);
      when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
      when(
        () => apiClient.post(any(), any()),
      ).thenAnswer((_) async => http.Response('{}', 200));
      when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
      when(() => rideBloc.add(any())).thenAnswer((_) {});
    });

    tearDown(() => formBloc.close());

    testWidgets('dispatches ClientPreselected for the logged-in user on mount', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          locale: const Locale('en'),
          home: Scaffold(
            body: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: ClientBookScreen(formBloc: formBloc, rideBloc: rideBloc),
            ),
          ),
        ),
      );
      await tester.pump();

      // The client books for themselves: both the selection and the baseline
      // must be the current user, and that is not counted as a "modification".
      expect(formBloc.state.selectedClientId, _client().id);
      expect(formBloc.state.baselineClientId, _client().id);
      expect(formBloc.state.clientName, _client().name);
      expect(formBloc.state.isModified, isFalse);
    });
  });

  group('Confirm booking enables once the client flow has addresses', () {
    // The button is `onPressed: state.isValid ? ... : null`. With the client
    // preselected (as the screen does on mount), entering two distinct,
    // non-airport addresses must make the form valid.
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'preselected client + addresses → isValid (button enabled)',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        // Mirrors ClientBookScreen.didChangeDependencies preselecting self.
        bloc.add(
          ClientPreselected(clientId: _client().id, clientName: _client().name),
        );
        bloc.add(const FromAddressChanged('Maximilianstrasse 10'));
        bloc.add(const ToAddressChanged('Marienplatz 1'));
      },
      verify: (bloc) {
        expect(bloc.state.selectedClientId, _client().id);
        expect(bloc.state.isAirportTransfer, isFalse);
        expect(
          bloc.state.isValid,
          isTrue,
          reason: 'client booking for self must be submittable',
        );
      },
    );
  });

  // Regression: with the keyboard open the address-picker sheet collapsed the
  // results list to a single row — the sheet height was a fraction of the FULL
  // screen (DraggableScrollableSheet) and ignored the keyboard, so the list +
  // Confirm button were pushed behind the keyboard. The fix subtracts the
  // keyboard inset from the sheet's own height, so the search field, the list
  // and the Confirm button share the space ABOVE the keyboard and the list
  // keeps its room. (An earlier attempt wrapped a full-height sheet in
  // Padding(bottom: inset), which overflowed by ~6px — hence the height cap.)
  group('Address picker sheet survives the keyboard', () {
    late _MockAuthBloc authBloc;
    late _MockRideBloc rideBloc;
    late _MockApiClient apiClient;
    late _MockSavedPlacesBloc savedPlacesBloc;
    late CreateRideFormBloc formBloc;

    setUp(() {
      authBloc = _MockAuthBloc();
      rideBloc = _MockRideBloc();
      apiClient = _MockApiClient();
      savedPlacesBloc = _MockSavedPlacesBloc();
      formBloc = CreateRideFormBloc();

      when(() => authBloc.apiClient).thenReturn(apiClient);
      when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
      when(
        () => apiClient.post(any(), any()),
      ).thenAnswer((_) async => http.Response('{}', 200));
      when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
      when(() => rideBloc.add(any())).thenAnswer((_) {});
      when(() => savedPlacesBloc.state).thenReturn(
        SavedPlacesState.loaded([
          _savedPlace('Home', 'Maximilianstraße 10, 80539 München'),
          _savedPlace('Airport', 'Flughafen München Terminal 2, 85356 München'),
          _savedPlace('Office', 'Petuelring 130, 80788 München'),
        ]),
      );
    });

    tearDown(() => formBloc.close());

    testWidgets(
      'keyboard open: no overflow, and the results list keeps multiple rows',
      (tester) async {
        // iPhone-class viewport (≈874 logical tall) with a realistic keyboard
        // inset (~336 logical) occupying the bottom — the condition shown in the
        // bug report where the list collapsed to a single row.
        tester.view.physicalSize = const Size(1206, 2622);
        tester.view.devicePixelRatio = 3.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 1008); // ≈336 dp
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            locale: const Locale('en'),
            home: Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<AuthBloc>.value(value: authBloc),
                  BlocProvider<SavedPlacesBloc>.value(value: savedPlacesBloc),
                ],
                child: ClientBookScreen(formBloc: formBloc, rideBloc: rideBloc),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open the address picker via the FROM field.
        await tester.tap(find.text('Pickup location'));
        await tester.pumpAndSettle();

        // Search field and Confirm button are visible above the keyboard.
        expect(find.text('Enter pick-up address'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Confirm'), findsOneWidget);

        // The list is not collapsed: with 3 seeded saved places, the keyboard-
        // aware sheet height leaves the Expanded list enough room to show more
        // than one entry. All three München addresses must be in the tree.
        expect(find.textContaining('München'), findsAtLeastNWidgets(2));

        // No RenderFlex overflow (or any other) exception while laying out with
        // the keyboard inset applied.
        expect(tester.takeException(), isNull);
      },
    );
  });

  // Regression: after a ride was created successfully, the form was left with
  // the entered addresses, so isModified stayed true and the "Discard changes?"
  // dialog wrongly appeared the next time the user left the Book tab. The screen
  // must clear the form (FormCleared) when RideBloc reports `created`.
  group('Form is cleared after a successful booking', () {
    late _MockAuthBloc authBloc;
    late _MockRideBloc rideBloc;
    late _MockApiClient apiClient;
    late CreateRideFormBloc formBloc;

    setUp(() {
      authBloc = _MockAuthBloc();
      rideBloc = _MockRideBloc();
      apiClient = _MockApiClient();
      formBloc = CreateRideFormBloc();

      when(() => authBloc.apiClient).thenReturn(apiClient);
      when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
      when(
        () => apiClient.post(any(), any()),
      ).thenAnswer((_) async => http.Response('{}', 200));
    });

    tearDown(() => formBloc.close());

    testWidgets(
      'RideStateStatus.created clears the form (no unsaved details)',
      (tester) async {
        // Drive RideBloc's state stream by hand so we control exactly when the
        // `created` transition happens — and so we can close it cleanly at the
        // end (a Stream.fromIterable races MockBloc's own sink on teardown).
        final rideStates = StreamController<RideState>.broadcast();
        addTearDown(rideStates.close);
        whenListen(
          rideBloc,
          rideStates.stream,
          initialState: RideState.loaded(const []),
        );

        var onCreatedCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            locale: const Locale('en'),
            home: Scaffold(
              body: BlocProvider<AuthBloc>.value(
                value: authBloc,
                child: ClientBookScreen(
                  formBloc: formBloc,
                  rideBloc: rideBloc,
                  onCreated: () => onCreatedCalls++,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // The form starts dirty: the client is preselected on mount and both
        // addresses are filled, exactly as it is right before a successful
        // booking. Use a plain pump (not pumpAndSettle) — the estimate calls
        // fire-and-forget futures that pumpAndSettle would wait on forever.
        formBloc.add(const FromAddressChanged('Maximilianstraße 10'));
        formBloc.add(const ToAddressChanged('Flughafen München Terminal 2'));
        await tester.pump();
        expect(
          formBloc.state.isModified,
          isTrue,
          reason: 'precondition: the form has unsaved details before booking',
        );

        // RideBloc reports a successful creation.
        rideStates.add(const RideState(status: RideStateStatus.created));
        await tester.pump();

        // The booking flow ran: the success callback fired and, crucially, the
        // form was reset so nothing counts as unsaved anymore.
        expect(onCreatedCalls, 1);
        expect(
          formBloc.state.isModified,
          isFalse,
          reason: 'a persisted ride leaves no unsaved details to discard',
        );
        expect(formBloc.state.fromAddress, isEmpty);
        expect(formBloc.state.toAddress, isEmpty);
      },
    );
  });

  // One-tap saved places: the booking picker shows a labelled quick-pick
  // section (Home/Office/...). Tapping "Home" selects that place's *address*
  // for the field (the label is just the display title).
  group('Saved places one-tap in the booking picker', () {
    late _MockAuthBloc authBloc;
    late _MockRideBloc rideBloc;
    late _MockApiClient apiClient;
    late _MockSavedPlacesBloc savedPlacesBloc;
    late CreateRideFormBloc formBloc;

    const homeAddress = 'Maximilianstraße 10, 80539 München';

    setUp(() {
      authBloc = _MockAuthBloc();
      rideBloc = _MockRideBloc();
      apiClient = _MockApiClient();
      savedPlacesBloc = _MockSavedPlacesBloc();
      formBloc = CreateRideFormBloc();

      when(() => authBloc.apiClient).thenReturn(apiClient);
      when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
      when(
        () => apiClient.post(any(), any()),
      ).thenAnswer((_) async => http.Response('{}', 200));
      when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
      when(() => rideBloc.add(any())).thenAnswer((_) {});
      when(() => savedPlacesBloc.state).thenReturn(
        SavedPlacesState.loaded([
          _savedPlace('Home', homeAddress),
          _savedPlace('Office', 'Petuelring 130, 80788 München'),
        ]),
      );
    });

    tearDown(() => formBloc.close());

    testWidgets('tapping "Home" sets the FROM field to the home address', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          locale: const Locale('en'),
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>.value(value: authBloc),
                BlocProvider<SavedPlacesBloc>.value(value: savedPlacesBloc),
              ],
              child: ClientBookScreen(formBloc: formBloc, rideBloc: rideBloc),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the picker via the FROM field.
      await tester.tap(find.text('Pickup location'));
      await tester.pumpAndSettle();

      // The labelled tile shows the label as title — tap it.
      expect(find.text('Home'), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pump();

      // The address (not the label) landed in the FROM field.
      expect(formBloc.state.fromAddress, homeAddress);
    });
  });
}
