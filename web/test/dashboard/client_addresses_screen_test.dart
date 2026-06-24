import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/dashboard/client/client_addresses_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _client() => Person(
  id: 'client-1',
  name: 'Bruno Aldi',
  email: 'bruno@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
  phone: '+491234567890',
);

const _addressesJson =
    '[{"id":"a1","clientId":"client-1","label":"Home",'
    '"address":"Leopoldstr. 21","useCount":1,"aliases":[],'
    '"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z"},'
    '{"id":"a2","clientId":"client-1","label":"Gym",'
    '"address":"Sportplatz 7","useCount":1,"aliases":[],'
    '"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z"}]';

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
    when(() => apiClient.dispose()).thenReturn(null);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const ClientAddressesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists all saved places (fixed + custom) and an add row', (
    tester,
  ) async {
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response(_addressesJson, 200));

    await pump(tester);

    // Both the fixed Home slot and the custom Gym place are listed here (this
    // is the full management screen, unlike the home "My addresses" list which
    // hides the fixed slots).
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Leopoldstr. 21'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Add new place'), findsOneWidget);
  });

  testWidgets('tapping a place opens the Use/Edit/Remove menu', (tester) async {
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response(_addressesJson, 200));

    await pump(tester);

    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();

    expect(find.text('Use this address'), findsOneWidget);
    expect(find.text('Edit address'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('empty list still shows the add row', (tester) async {
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));

    await pump(tester);

    expect(find.text('Add new place'), findsOneWidget);
  });
}
