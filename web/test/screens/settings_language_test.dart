import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/locale_notifier.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

// --- Mocks ---

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

// --- Fixture ---

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

    // Stub GET /sessions so initState doesn't throw.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));

    // Default: auth state with a logged-in user.
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_testUser()));

    // Reset locale to a known value before each test.
    localeNotifier.value = null;
  });

  tearDown(() {
    // Restore locale so other tests are not affected.
    localeNotifier.value = null;
  });

  /// Builds a [MaterialApp] wrapping [SettingsScreen] with all required BLoCs.
  Widget buildApp() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: const SettingsScreen(),
    ),
  );

  // ---------------------------------------------------------------------------
  // Helper: open the language bottom sheet and tap an entry.
  // ---------------------------------------------------------------------------
  Future<void> openLanguagePickerAndTap(
    WidgetTester tester,
    String languageLabel,
  ) async {
    // The Language row is built with InkWell + Text, not a ListTile.
    // Tap the "Language" text to open the bottom sheet.
    final languageText = find.text('Language');
    expect(
      languageText,
      findsOneWidget,
      reason: '"Language" row must be present',
    );
    await tester.tap(languageText);
    await tester.pumpAndSettle();

    // Tap the desired language entry in the bottom sheet (standard ListTile).
    final entry = find.widgetWithText(ListTile, languageLabel);
    expect(
      entry,
      findsOneWidget,
      reason: '$languageLabel must appear in picker',
    );
    await tester.tap(entry);
    // Allow async onTap (including the awaited PUT) to complete.
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------------
  // Case 1 — success: PUT succeeds, locale is applied, no snackbar.
  // ---------------------------------------------------------------------------
  testWidgets('language picker success: PUT is called once and locale updates; '
      'no error snackbar is shown', (tester) async {
    // Stub a successful PUT.
    when(
      () => apiClient.put('/users/user-123', {'preferredLanguage': 'de'}),
    ).thenAnswer((_) async => http.Response('{}', 200));

    await tester.pumpWidget(buildApp());
    await tester.pump();

    await openLanguagePickerAndTap(tester, 'Deutsch');

    // PUT must have been called exactly once with the correct payload.
    verify(
      () => apiClient.put('/users/user-123', {'preferredLanguage': 'de'}),
    ).called(1);

    // Locale notifier must reflect the selection.
    expect(
      localeNotifier.value,
      equals(const Locale('de')),
      reason: 'localeNotifier must be updated to de on success',
    );

    // No error snackbar must appear.
    expect(find.byType(SnackBar), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Case 2 — failure: PUT throws, locale still applies, snackbar is shown.
  // ---------------------------------------------------------------------------
  testWidgets(
    'language picker failure: PUT throws, locale is still applied optimistically '
    'and an error snackbar is shown',
    (tester) async {
      // Stub the PUT to throw a network error.
      when(
        () => apiClient.put('/users/user-123', {'preferredLanguage': 'uk'}),
      ).thenThrow(Exception('Network error'));

      await tester.pumpWidget(buildApp());
      await tester.pump();

      await openLanguagePickerAndTap(tester, 'Ukrainian');

      // Locale must still be updated optimistically despite the error.
      expect(
        localeNotifier.value,
        equals(const Locale('uk')),
        reason: 'localeNotifier must be updated even when the PUT fails',
      );

      // A SnackBar with the failure message must appear.
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'A SnackBar must be shown when PUT fails',
      );
      expect(
        find.text("Couldn't save language to your account"),
        findsOneWidget,
        reason: 'SnackBar must contain the languageSaveFailed message',
      );
    },
  );
}
