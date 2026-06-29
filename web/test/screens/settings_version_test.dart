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
import 'package:package_info_plus/package_info_plus.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();

    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_testUser()));

    // /sessions (called in initState) — keep it boring.
    when(
      () => apiClient.get('/sessions'),
    ).thenAnswer((_) async => http.Response('[]', 200));

    // The app's own version (PackageInfo) read in initState.
    PackageInfo.setMockInitialValues(
      appName: 'Dispax',
      packageName: 'de.dispax.app',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  Widget buildApp() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: const SettingsScreen(),
    ),
  );

  testWidgets('About section shows app version and backend version', (
    tester,
  ) async {
    when(() => apiClient.get('/version')).thenAnswer(
      (_) async => http.Response(
        '{"version":"0.1.0","commit":"a1b2c3d","branch":"master","buildTime":"2026-06-29T06:23:24Z"}',
        200,
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Scroll to the About section at the bottom of the list.
    await tester.scrollUntilVisible(
      find.text('App version'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('App version'), findsOneWidget);
    expect(find.text('1.2.3 (build 42)'), findsOneWidget);
    expect(find.text('Backend version'), findsOneWidget);
    expect(find.text('0.1.0 +a1b2c3d'), findsOneWidget);
  });

  testWidgets('Backend version falls back to a dash when the API fails', (
    tester,
  ) async {
    when(
      () => apiClient.get('/version'),
    ).thenAnswer((_) async => http.Response('{"error":"boom"}', 500));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Backend version'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    // App version still resolves from PackageInfo...
    expect(find.text('1.2.3 (build 42)'), findsOneWidget);
    // ...but the backend row degrades gracefully.
    expect(find.text('—'), findsOneWidget);
  });
}
