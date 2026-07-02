// Phase 4 render proof: a screen that stores its load error in an `Object?
// _error` field and shows it via `friendlyError(_error, l10n)` must render the
// localized, non-technical message — not the raw exception. NotificationsScreen
// is the representative for the ~30 `_error`-field screens migrated in Phase 4.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _user() => Person(
  id: 'u-1',
  name: 'Test',
  email: 't@example.com',
  role: PersonRole.dispatcher,
  companyId: 'c-1',
  phone: '+490000000000',
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_user()));
    when(() => authBloc.apiClient).thenReturn(apiClient);
  });

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: const NotificationsScreen(),
    ),
  );

  testWidgets('load timeout renders the friendly timeout text, no raw leak', (
    tester,
  ) async {
    when(() => apiClient.get(any())).thenThrow(
      ApiException(
        'Failed to perform GET request to https://x/api/notifications: '
        'TimeoutException after 0:00:15.000000: Future not completed',
        cause: TimeoutException('t'),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(host());
    await tester.pump(); // let the async load + setState settle
    await tester.pump();

    expect(find.text(l10n.errorTimeout), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
    expect(find.textContaining('TimeoutException'), findsNothing);
    expect(find.textContaining('/api/'), findsNothing);
  });

  testWidgets(
    'non-200 renders a friendly server message, not the status code',
    (tester) async {
      when(
        () => apiClient.get(any()),
      ).thenAnswer((_) async => http.Response('nope', 503));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.errorServer), findsOneWidget);
      expect(find.textContaining('503'), findsNothing);
    },
  );
}
