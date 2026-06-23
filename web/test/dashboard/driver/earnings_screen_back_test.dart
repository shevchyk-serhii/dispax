import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/dashboard/driver/earnings_screen.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
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
  id: 'driver-1',
  name: 'Test Driver',
  email: 'driver@example.com',
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
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_testUser()));

    // Stub the earnings GET so the cubit's load() resolves; the fromJson
    // factory tolerates an empty object (every field has a default).
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('{"grossRevenue": 70.0}', 200));
  });

  /// EarningsScreen wrapped with its required AuthBloc.
  Widget earningsScreen() => BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: const EarningsScreen(),
  );

  // The back arrow uses Icons.arrow_back_ios_new — same affordance as the
  // SettingsScreen graphite header.
  final backArrow = find.byIcon(Icons.arrow_back_ios_new);

  testWidgets(
    'shows a back arrow when EarningsScreen is pushed onto the stack',
    (tester) async {
      // A host screen that pushes EarningsScreen, so Navigator.canPop() is true.
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => earningsScreen()),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        backArrow,
        findsOneWidget,
        reason: 'pushed EarningsScreen must show a back affordance',
      );
    },
  );

  testWidgets('tapping the back arrow pops EarningsScreen off the stack', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => earningsScreen()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(backArrow, findsOneWidget);

    await tester.tap(backArrow);
    await tester.pumpAndSettle();

    // Back on the host screen; EarningsScreen is gone.
    expect(find.text('open'), findsOneWidget);
    expect(backArrow, findsNothing);
  });

  testWidgets('no back arrow when EarningsScreen is the root (cannot pop)', (
    tester,
  ) async {
    // EarningsScreen as the root route: Navigator.canPop() is false.
    await tester.pumpWidget(MaterialApp(home: earningsScreen()));
    await tester.pumpAndSettle();

    expect(
      backArrow,
      findsNothing,
      reason: 'a root EarningsScreen must not show a back affordance',
    );
  });
}
