import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _user(PersonRole role) => Person(
  id: 'user-1',
  name: 'Test User',
  email: 'test@example.com',
  role: role,
  companyId: 'company-1',
  roles: {role},
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);
    // GET /sessions in initState.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));
  });

  Future<void> pumpFor(WidgetTester tester, PersonRole role) async {
    // A tall viewport so the lazy ListView materialises every section — the
    // saved-addresses row sits below the fold and would otherwise not be built,
    // making the gating test insensitive (a false negative for the driver case).
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    when(() => authBloc.state).thenReturn(AuthState.authenticated(_user(role)));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('client sees the "Saved addresses" management row', (
    tester,
  ) async {
    await pumpFor(tester, PersonRole.client);
    // Row label + section label both use the same string.
    expect(find.text('Saved addresses'), findsWidgets);
  });

  testWidgets('non-client (driver) does not see the saved addresses row', (
    tester,
  ) async {
    await pumpFor(tester, PersonRole.driver);
    expect(find.text('Saved addresses'), findsNothing);
  });
}
