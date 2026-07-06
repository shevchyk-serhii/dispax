// Widget tests for the client-selection section of the create-ride form
// (`CreateRideBasicInfoSection`).
//
// The inline "New client" create path (name + phone) used to be driver-only;
// every other booking role only got the existing-client search field. It is now
// shared: driver, dispatcher and secretary all see the "New client" toggle, so a
// dispatcher/secretary can add a walk-in client without leaving the form. A
// client (booking for themselves) still sees nothing here.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/widgets/sections/create_ride_basic_info_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  late CreateRideFormBloc formBloc;
  late MockAuthBloc authBloc;
  late ApiClient apiClient;

  setUp(() {
    formBloc = CreateRideFormBloc();
    authBloc = MockAuthBloc();
    // The section builds a UserService from the AuthBloc's apiClient in
    // initState; a real (unused) ApiClient is enough — no HTTP is issued here.
    apiClient = ApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);
  });

  tearDown(() {
    formBloc.close();
  });

  // Pumps the section with [role] as the authenticated user's role.
  Future<void> pumpSection(WidgetTester tester, PersonRole role) async {
    final user = TestFixtures.person(role: role);
    final state = AuthState.authenticated(user);
    when(() => authBloc.state).thenReturn(state);
    whenListen(authBloc, Stream<AuthState>.value(state), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<CreateRideFormBloc>.value(value: formBloc),
            ],
            child: const SingleChildScrollView(
              child: CreateRideBasicInfoSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dispatcher sees the "New client" inline-create toggle', (
    tester,
  ) async {
    await pumpSection(tester, PersonRole.secretary);

    // The inline-create affordance is now available to non-driver booking roles.
    expect(find.text('New client'), findsOneWidget);
  });

  testWidgets('driver still sees the "New client" toggle', (tester) async {
    await pumpSection(tester, PersonRole.driver);
    expect(find.text('New client'), findsOneWidget);
  });

  testWidgets('a client (booking for themselves) sees no client section', (
    tester,
  ) async {
    await pumpSection(tester, PersonRole.client);

    // The whole section collapses for a client — no toggle at all.
    expect(find.text('New client'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });
}
