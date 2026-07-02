// UserAppBar hardcoded the per-role dashboard title and the "Logout" menu item
// in English, so they stayed English when the user picked German. This locks
// the German rendering of the title (per role) and the logout action.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/dashboard/widgets/user_app_bar.dart';

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  late MockApiClient mockApiClient;
  late AuthBloc authBloc;

  setUp(() {
    mockApiClient = MockApiClient();
    authBloc = AuthBloc(apiClient: mockApiClient);
  });

  tearDown(() => authBloc.close());

  Widget wrap(Person user) => BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: UserAppBar(user: user, onLogout: () {}, onProfile: () {}),
      ),
    ),
  );

  testWidgets('dispatcher title is German', (tester) async {
    await tester.pumpWidget(
      wrap(TestFixtures.person(role: PersonRole.dispatcher)),
    );
    await tester.pump();

    expect(find.text('Dispatcher-Dashboard'), findsOneWidget);
    expect(find.text('Dispatcher Dashboard'), findsNothing);
  });

  testWidgets('driver title is German', (tester) async {
    await tester.pumpWidget(wrap(TestFixtures.person(role: PersonRole.driver)));
    await tester.pump();

    expect(find.text('Fahrer-Dashboard'), findsOneWidget);
    expect(find.text('Driver Dashboard'), findsNothing);
  });

  testWidgets('logout menu item is German', (tester) async {
    await tester.pumpWidget(
      wrap(TestFixtures.person(role: PersonRole.dispatcher)),
    );
    await tester.pump();

    // Open the avatar popup menu.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Abmelden'), findsOneWidget); // Logout
    expect(find.text('Logout'), findsNothing);
  });
}
