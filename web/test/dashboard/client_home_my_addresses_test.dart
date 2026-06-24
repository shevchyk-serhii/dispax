import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/blocs/saved_places/saved_places_bloc.dart';
import 'package:dispax/blocs/saved_places/saved_places_event.dart';
import 'package:dispax/blocs/saved_places/saved_places_state.dart';
import 'package:dispax/dashboard/client/client_home_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/client_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockSavedPlacesBloc extends MockBloc<SavedPlacesEvent, SavedPlacesState>
    implements SavedPlacesBloc {}

class _MockApiClient extends Mock implements ApiClient {}

class _FakeSavedPlacesEvent extends Fake implements SavedPlacesEvent {}

class _FakeRideEvent extends Fake implements RideEvent {}

ClientAddress _place(String label, String address) => ClientAddress(
  id: 'addr-$label',
  clientId: 'client-1',
  label: label,
  address: address,
  useCount: 1,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

Person _client() => Person(
  id: 'client-1',
  name: 'Bruno Aldi',
  email: 'bruno@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
  phone: '+491234567890',
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSavedPlacesEvent());
    registerFallbackValue(_FakeRideEvent());
  });

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;
  late _MockSavedPlacesBloc savedBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    savedBloc = _MockSavedPlacesBloc();
    apiClient = _MockApiClient();

    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
    // _LiveRideCard reads RideBloc; loaded([]) avoids the initial auto-load.
    when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
    when(() => rideBloc.add(any())).thenAnswer((_) {});
    when(() => savedBloc.add(any())).thenAnswer((_) {});
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<RideBloc>.value(value: rideBloc),
            BlocProvider<SavedPlacesBloc>.value(value: savedBloc),
          ],
          child: ClientHomeScreen(onBookTap: () {}),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('custom places (non Home/Office/Airport) render in the list', (
    tester,
  ) async {
    when(() => savedBloc.state).thenReturn(
      SavedPlacesState.loaded([
        _place('Home', 'Leopoldstr. 21'),
        _place('Gym', 'Sportplatz 7'),
      ]),
    );
    await pumpHome(tester);

    // The custom "Gym" place shows; the fixed "Home" slot is NOT duplicated in
    // the My Addresses list (it lives in the saved-places row instead).
    expect(find.text('MY ADDRESSES'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Sportplatz 7'), findsOneWidget);
    // "Home" appears once (the fixed slot), not again in the custom list.
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Add address button is always shown', (tester) async {
    when(() => savedBloc.state).thenReturn(SavedPlacesState.loaded(const []));
    await pumpHome(tester);

    expect(find.text('Add new place'), findsOneWidget);
  });

  testWidgets('Add address: empty label is rejected (no save dispatched)', (
    tester,
  ) async {
    when(() => savedBloc.state).thenReturn(SavedPlacesState.loaded(const []));
    await pumpHome(tester);

    await tester.tap(find.text('Add new place'));
    await tester.pumpAndSettle();

    // Submit with an empty label — the validator blocks it.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a label'), findsOneWidget);
    verifyNever(() => savedBloc.add(any()));
  });
}
