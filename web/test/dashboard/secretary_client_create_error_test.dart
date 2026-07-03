// Regression tests for a FAILED client creation while the list is empty
// (fresh company onboarding — e.g. duplicate email 409).
//
// The bug: ClientListPanel's mutation SnackBar listener was gated by
// `current.clients.isNotEmpty`, and the BlocBuilder rendered the full-screen
// "Error loading data" view whenever `hasError && clients.isEmpty`. So the
// FIRST client's failed creation produced a false full-screen LOAD error
// (whose Retry reloads the list, not the creation), the create dialog had
// already been popped unconditionally, and the entered data + generated temp
// password were gone.
//
// Uses a REAL ClientBloc with a mocked UserService so the whole flow
// (dialog → event → mutation-error state → UI) is exercised.

import 'package:dispax/blocs/client/client_bloc.dart';
import 'package:dispax/dashboard/secretary/widgets/client_list_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/billing/services/client_company_service.dart';
import 'package:dispax/modules/core/models/user_requests.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

class _MockUserService extends Mock implements UserService {}

class _MockClientCompanyService extends Mock implements ClientCompanyService {}

class _FakeCreateUserRequest extends Fake implements CreateUserRequest {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeCreateUserRequest()));

  late _MockUserService userService;
  late _MockClientCompanyService companyService;
  late ClientBloc bloc;

  setUp(() {
    userService = _MockUserService();
    companyService = _MockClientCompanyService();
    when(() => userService.dispose()).thenReturn(null);
    when(() => companyService.getCompanies()).thenAnswer((_) async => []);
    // Fresh company: the list is empty.
    when(() => userService.getClients()).thenAnswer((_) async => []);
  });

  Widget buildSubject() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: BlocProvider<ClientBloc>.value(
      value: bloc,
      child: ClientListPanel(companyService: companyService),
    ),
  );

  Finder fieldByLabel(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

  Future<void> submitFirstClient(WidgetTester tester) async {
    // The bloc MUST be created inside the test body: a bloc built in setUp()
    // lives outside the test's FakeAsync zone, so its awaited service futures
    // never resume and the create stays stuck in `loading` forever.
    bloc = ClientBloc(userService: userService);
    addTearDown(bloc.close);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(fieldByLabel('Name'), 'First Client');
    await tester.enterText(fieldByLabel('Email'), 'dup@example.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    // Bounded pumps, NOT pumpAndSettle: settling would also play out the
    // SnackBar's auto-dismiss, so the assertion below would never see it.
    await tester.pump(); // create dispatched → loading
    await tester.pump(); // create settled → loaded / error
    await tester.pump(const Duration(milliseconds: 400)); // animations
  }

  testWidgets(
    'failed FIRST create shows a SnackBar, not the full-screen load error',
    (tester) async {
      when(() => userService.createClient(any())).thenThrow(
        ApiException(
          'Create client: Email already registered',
          statusCode: 409,
        ),
      );

      await submitFirstClient(tester);

      // No false full-screen "Error loading data" view.
      expect(
        find.text('Error loading data'),
        findsNothing,
        reason:
            'A failed CREATE must not render the full-screen LOAD error — '
            'its Retry reloads the list, not the creation',
      );
      // The mutation failure is surfaced as a SnackBar even though the list
      // is empty.
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets('failed create keeps the dialog open with the entered data', (
    tester,
  ) async {
    when(() => userService.createClient(any())).thenThrow(
      ApiException('Create client: Email already registered', statusCode: 409),
    );

    await submitFirstClient(tester);

    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason:
          'The create dialog must stay open on failure so the entered data '
          'and the generated temp password are not lost',
    );
    expect(find.text('First Client'), findsOneWidget);
    expect(find.text('dup@example.com'), findsOneWidget);
  });

  testWidgets('successful create closes the dialog', (tester) async {
    when(() => userService.createClient(any())).thenAnswer(
      (_) async => TestFixtures.person(id: 'client-1', name: 'First Client'),
    );

    await submitFirstClient(tester);

    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'On success the dialog must still close as before',
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Error loading data'), findsNothing);
  });
}
