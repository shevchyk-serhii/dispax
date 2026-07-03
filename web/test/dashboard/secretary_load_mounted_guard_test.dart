// Regression tests: async loaders that call setState after an await must guard
// on `mounted`. Opening a screen and navigating away before the request
// completes previously crashed with "setState() called after dispose()" in
// - ClientDetailScreen._loadRides (secretary client detail),
// - CompanySettingsScreen._loadSettings,
// - SecretaryReportsPanel._loadStats.
// Also: a non-200 stats response must surface an error with Retry, not a
// silent blank panel.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/dashboard/secretary/widgets/client_detail_screen.dart';
import 'package:dispax/dashboard/secretary/widgets/secretary_reports_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/screens/company_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

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

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: Scaffold(body: child),
    ),
  );

  /// Pumps [screen], disposes it while the GET is still in flight, then
  /// completes the request. Fails if the loader calls setState after dispose.
  Future<void> disposeMidLoad(
    WidgetTester tester,
    Widget screen, {
    required Completer<http.Response> completer,
    bool completeWithError = false,
  }) async {
    await tester.pumpWidget(wrap(screen));
    // The request is pending — replace the tree so the State is disposed.
    await tester.pumpWidget(wrap(const SizedBox.shrink()));

    if (completeWithError) {
      completer.completeError(Exception('network down'));
    } else {
      completer.complete(http.Response('[]', 200));
    }
    // Let the loader's async continuation run.
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  }

  group('ClientDetailScreen._loadRides', () {
    testWidgets('dispose mid-load (success path) does not throw', (
      tester,
    ) async {
      final completer = Completer<http.Response>();
      when(() => api.get(any())).thenAnswer((_) => completer.future);
      await disposeMidLoad(
        tester,
        ClientDetailScreen(client: TestFixtures.person()),
        completer: completer,
      );
    });

    testWidgets('dispose mid-load (error path) does not throw', (tester) async {
      final completer = Completer<http.Response>();
      when(() => api.get(any())).thenAnswer((_) => completer.future);
      await disposeMidLoad(
        tester,
        ClientDetailScreen(client: TestFixtures.person()),
        completer: completer,
        completeWithError: true,
      );
    });
  });

  group('CompanySettingsScreen._loadSettings', () {
    testWidgets('dispose mid-load (success path) does not throw', (
      tester,
    ) async {
      final completer = Completer<http.Response>();
      when(() => api.get(any())).thenAnswer((_) => completer.future);
      await disposeMidLoad(
        tester,
        const CompanySettingsScreen(),
        completer: completer,
      );
    });

    testWidgets('dispose mid-load (error path) does not throw', (tester) async {
      final completer = Completer<http.Response>();
      when(() => api.get(any())).thenAnswer((_) => completer.future);
      await disposeMidLoad(
        tester,
        const CompanySettingsScreen(),
        completer: completer,
        completeWithError: true,
      );
    });
  });

  group('SecretaryReportsPanel._loadStats', () {
    testWidgets('dispose mid-load (success path) does not throw', (
      tester,
    ) async {
      final completer = Completer<http.Response>();
      when(() => api.get(any())).thenAnswer((_) => completer.future);
      await disposeMidLoad(
        tester,
        const SecretaryReportsPanel(),
        completer: completer,
      );
    });

    testWidgets('dispose mid-load (error path) does not throw', (tester) async {
      final completer = Completer<http.Response>();
      when(() => api.get(any())).thenAnswer((_) => completer.future);
      await disposeMidLoad(
        tester,
        const SecretaryReportsPanel(),
        completer: completer,
        completeWithError: true,
      );
    });

    testWidgets('non-200 stats response shows the error state with Retry, '
        'not a blank panel', (tester) async {
      when(
        () => api.get(any()),
      ).thenAnswer((_) async => http.Response('oops', 500));

      await tester.pumpWidget(wrap(const SecretaryReportsPanel()));
      await tester.pumpAndSettle();

      // The error branch renders an icon + message + Retry button.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
