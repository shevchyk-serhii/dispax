// Regression: the work-hours fields used raw `as int` casts
// (settings['workStartHour'] as int). If the backend response decodes the
// hour as a double (8.0 — a perfectly valid JSON serialization of 8), the
// cast threw and the WHOLE settings loader fell into the error state. The
// parse must tolerate num and convert (toInt).

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/screens/company_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late MockApiClient api;
  late _MockAuthBloc authBloc;

  setUp(() {
    api = MockApiClient();
    authBloc = _MockAuthBloc();
    when(() => authBloc.apiClient).thenReturn(api);
    when(() => authBloc.state).thenReturn(AuthState.initial());
  });

  testWidgets('double-serialized work hours (8.0) load instead of failing '
      'into the error state', (tester) async {
    // Mobile layout (below the desktop breakpoint): its scroll content
    // includes the work-hours time pickers. Tall enough to build them.
    tester.view.physicalSize = const Size(700, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => api.get('/company/settings')).thenAnswer(
      (_) async => http.Response(
        '{"workStartHour": 8.0, "workStartMinute": 30.0,'
        ' "workEndHour": 22.0, "workEndMinute": 15.0}',
        200,
      ),
    );
    when(
      () => api.get('/company/tariff'),
    ).thenAnswer((_) async => http.Response('{}', 200));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const Scaffold(body: CompanySettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The loader must NOT fall into the error state…
    expect(
      find.byIcon(Icons.error_outline),
      findsNothing,
      reason: 'a double-typed hour must not crash the settings load',
    );
    // …and the parsed times must be applied to the pickers.
    expect(find.text('8:30 AM'), findsOneWidget);
    expect(find.text('10:15 PM'), findsOneWidget);
  });
}
