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

  // Regression: the address-picker bottom sheet overflowed by a few pixels when
  // the keyboard appeared ("BOTTOM OVERFLOWED BY 6.4 PIXELS"), clipping the
  // Confirm button. The whole DraggableScrollableSheet was wrapped in a
  // Padding(bottom: viewInsets), double-counting the keyboard inset. The fix
  // applies the inset only to the Confirm button's bottom padding.
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

    testWidgets('builds without exceptions when the keyboard is open', (
      tester,
    ) async {
      // Simulate a small viewport with the keyboard occupying the bottom —
      // this is exactly the condition that triggered the overflow.
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 1000);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
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
      await tester.tap(find.text('Pick up location'));
      await tester.pumpAndSettle();

      // The sheet is up (its search field is visible) and the Confirm button
      // renders. The keyboard inset is now applied to the button's bottom
      // padding instead of wrapping the whole sheet, so the button stays above
      // the keyboard. (The exact ~6px overflow is device-geometry-specific and
      // is best caught by a golden/manual check; this is a smoke test that the
      // keyboard-aware sheet builds and lays out without exceptions.)
      expect(find.text('Enter pick-up address'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Confirm'), findsOneWidget);
      // No RenderFlex overflow (or any other) exception was thrown while the
      // keyboard inset is applied.
      expect(tester.takeException(), isNull);
    });
  });
}
