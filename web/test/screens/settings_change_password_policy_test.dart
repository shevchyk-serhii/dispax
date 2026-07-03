// Regression test for the change-password dialog in SettingsScreen: the
// client-side validator must mirror the backend policy (>=8 chars with an
// uppercase letter, a lowercase letter, and a digit — AuthService.scala
// validatePassword), instead of the old `< 6` length check that let weak
// passwords through to a raw 400.

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

Person _testUser() => Person(
  id: 'user-123',
  name: 'Test User',
  email: 'test@example.com',
  role: PersonRole.driver,
  companyId: 'company-1',
  roles: {PersonRole.driver},
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();

    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));
    when(
      () => apiClient.put(any(), any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_testUser()));
  });

  Widget buildSubject() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: const SettingsScreen(),
    ),
  );

  Future<void> openChangePasswordDialog(WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final tile = find.text(l10n.changePassword);
    await tester.scrollUntilVisible(tile, 200);
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'weak new password (old <6 check would pass it) blocks the request',
    (tester) async {
      await openChangePasswordDialog(tester);

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(3));

      await tester.enterText(fields.at(0), 'Current1');
      // 6 chars, no uppercase, no digit — rejected by the backend policy.
      await tester.enterText(fields.at(1), 'abcdef');
      await tester.enterText(fields.at(2), 'abcdef');

      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pump();

      verifyNever(() => apiClient.put('/users/change-password', any()));
    },
  );

  testWidgets('policy-compliant new password sends the request', (
    tester,
  ) async {
    await openChangePasswordDialog(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Current1');
    await tester.enterText(fields.at(1), 'NewPass123');
    await tester.enterText(fields.at(2), 'NewPass123');

    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    verify(() => apiClient.put('/users/change-password', any())).called(1);
  });
}
