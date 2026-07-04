// Regression test: money/tariff fields in CompanySettingsScreen must accept
// the German decimal comma. `double.tryParse` is locale-invariant, so
// "2,50" used to fall back to `?? 0` and the fee was silently zeroed.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/company_settings_screen.dart';
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
  role: PersonRole.dispatcher,
  companyId: 'company-1',
  roles: {PersonRole.dispatcher},
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();

    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_testUser()));
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
    when(
      () => apiClient.put(any(), any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
  });

  Widget buildSubject() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: const Scaffold(body: CompanySettingsScreen()),
    ),
  );

  Future<AppLocalizations> l10n() =>
      AppLocalizations.delegate.load(const Locale('en'));

  Future<void> enterAmountAndSave(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextField, label);
    await tester.scrollUntilVisible(
      field,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(field, value);

    await tester.tap(find.byIcon(Icons.save_outlined), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets('German decimal comma "2,50" is saved as 2.5, not 0', (
    tester,
  ) async {
    final loc = await l10n();
    await enterAmountAndSave(tester, loc.commissionRateLabel, '2,50');

    final payload =
        verify(
              () => apiClient.put('/company/settings', captureAny()),
            ).captured.single
            as Map<String, dynamic>;
    expect(payload['commissionRate'], 2.5);
  });

  testWidgets('German thousands+comma "1.234,56" is saved as 1234.56', (
    tester,
  ) async {
    final loc = await l10n();
    await enterAmountAndSave(tester, loc.basePriceLabel, '1.234,56');

    final payload =
        verify(
              () => apiClient.put('/company/tariff', captureAny()),
            ).captured.single
            as Map<String, dynamic>;
    expect(payload['basePrice'], 1234.56);
  });

  testWidgets('garbage in a money field aborts the save with an error', (
    tester,
  ) async {
    final loc = await l10n();
    await enterAmountAndSave(tester, loc.noShowFeeLabel, 'abc');

    verifyNever(() => apiClient.put(any(), any()));
    expect(find.text(loc.invalidAmountError), findsOneWidget);
  });

  // Regression: work-hour fields serialized as doubles (e.g. 6.0) used to hit a
  // raw `as int` cast and throw, dropping the whole settings load into the error
  // state. num->toInt tolerates both int and double serialization.
  testWidgets('work hours serialized as doubles load without crashing', (
    tester,
  ) async {
    when(() => apiClient.get('/company/settings')).thenAnswer(
      (_) async => http.Response(
        '{"workStartHour":6.0,"workStartMinute":30.0,'
        '"workEndHour":18.0,"workEndMinute":0.0}',
        200,
      ),
    );

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // A raw `as int` on 6.0 would throw, land in the catch and render the
    // full-screen error state (error icon + Retry). num->toInt parses cleanly,
    // so the settings form shows and the error state does not.
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    final loc = await l10n();
    expect(find.widgetWithText(ElevatedButton, loc.retry), findsNothing);
  });
}
