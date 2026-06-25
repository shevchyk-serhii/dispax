import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dispax/dashboard/driver/widgets/availability_toggle.dart';
import 'package:dispax/blocs/blocs.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';

// A minimal AuthBloc mock that returns a fixed state and a caller-supplied
// ApiClient so the toggle can load/update availability against MockClient.
class _FakeAuthBloc extends Fake implements AuthBloc {
  _FakeAuthBloc(this._state, this._apiClient);

  final AuthState _state;
  final ApiClient _apiClient;

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => Stream.value(_state);

  @override
  ApiClient get apiClient => _apiClient;

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() async {}
}

Person _driver() => Person(
      id: 'd1',
      name: 'Hans Weber',
      email: 'driver1@dispax.de',
      role: PersonRole.driver,
      companyId: 'c1',
    );

void main() {
  group('AvailabilityToggle', () {
    testWidgets('renders Switch.adaptive (Switch) when bloc has no user', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: BlocProvider<AuthBloc>.value(
            value: _FakeAuthBloc(const AuthState(), ApiClient()),
            child: const Scaffold(body: AvailabilityToggle()),
          ),
        ),
      );
      // initState calls _loadStatus, which reads user from bloc; user is null
      // so _loadStatus returns early. Widget renders with Switch.
      await tester.pump();

      // Switch.adaptive renders as Switch on non-iOS platforms in tests.
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets(
      'user toggle wins the race against the in-flight initial load '
      '(Switch does not snap back)',
      (tester) async {
        // Reproduces the reported bug: the driver opens the dashboard, the
        // initial GET /availability is still in flight (returns "Offline"),
        // the driver flips the Switch ON (PUT returns 204), and then the slow
        // GET resolves. The stale "Offline" load must NOT overwrite the user's
        // choice — the Switch must stay ON.
        final loadGate = Completer<void>();

        final apiClient = ApiClient(
          client: MockClient((req) async {
            if (req.method == 'GET') {
              // Hold the initial load until we release it after the toggle.
              await loadGate.future;
              return http.Response('{"status":"Offline"}', 200);
            }
            // PUT availability -> backend answers 204 No Content on success.
            return http.Response('', 204);
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: BlocProvider<AuthBloc>.value(
              value: _FakeAuthBloc(AuthState(user: _driver()), apiClient),
              child: const Scaffold(body: AvailabilityToggle()),
            ),
          ),
        );
        await tester.pump();

        // Initial state: Offline (load still pending).
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

        // Driver flips the Switch ON; PUT resolves 204, Switch becomes ON.
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Switch>(find.byType(Switch)).value,
          isTrue,
          reason: 'Switch should be ON right after a successful toggle',
        );

        // Now the slow initial load resolves with the stale "Offline" value.
        loadGate.complete();
        await tester.pumpAndSettle();

        // The Switch must remain ON — the late, stale load must be ignored.
        expect(
          tester.widget<Switch>(find.byType(Switch)).value,
          isTrue,
          reason: 'stale initial load must not snap the Switch back to OFF',
        );
      },
    );
  });
}
