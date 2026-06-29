// Widget test for the date+time picker in the ride edit dialog
// (NavigationUtils.navigateToEditRide).
//
// Feature: the pickup date/time used to be a plain text field requiring the
// strict format yyyy-MM-ddTHH:mm. It is now a tappable field that opens a
// Material date picker followed by a time picker, so the dispatcher never types
// a date. These tests pin:
//   1. picking a date+time sends the correct UTC ISO-8601 in the PUT body;
//   2. the dialog opens for a *past* ride without a showDatePicker assertion
//      (the picker window must be clamped around the ride's own date).

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/navigation_utils.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
  });

  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();

    when(() => authBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.state).thenReturn(
      AuthState.authenticated(
        TestFixtures.driver(id: 'dispatcher-1', name: 'Dispatcher Iryna'),
      ),
    );
    when(() => authBloc.apiClient).thenReturn(apiClient);
  });

  // The dialog is shown on the root navigator (above `home`), so AuthBloc must
  // be provided above the navigator via `builder` — mirroring AppRoot.
  Widget buildHost(Ride ride) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) =>
        BlocProvider<AuthBloc>.value(value: authBloc, child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => NavigationUtils.navigateToEditRide(context, ride),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'picking a date+time sends the matching UTC ISO-8601 in the PUT body',
    (tester) async {
      // A ride at a known local time with a minute (:32) that is NOT a multiple
      // of 5. The time picker is seeded with the rounded value (:30), so tapping
      // OK without changing anything must store 14:30 — proving the picker result
      // actually flows into the dialog state (a no-op assignment would leave :32).
      final ride = TestFixtures.ride(
        id: 'ride-7',
        pickupDateTime: DateTime(2026, 7, 15, 14, 32),
      );
      final expectedLocal = DateTime(2026, 7, 15, 14, 30);

      late Map<String, dynamic> sentBody;
      when(() => apiClient.put(any(), any())).thenAnswer((invocation) async {
        sentBody = invocation.positionalArguments[1] as Map<String, dynamic>;
        return http.Response(jsonEncode(ride.toJson()), 200);
      });

      await tester.pumpWidget(buildHost(ride));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ElevatedButton).first),
      )!;

      // Tap the date field → date picker → OK (keeps the same date). The picker
      // buttons come from MaterialLocalizations; the default test locale is en.
      await tester.tap(find.byKey(const Key('edit-ride-pickup-datetime')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The time picker follows → OK (keeps the same time).
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Save.
      await tester.tap(find.text(l10n.save));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      verify(() => apiClient.put('/rides/ride-7', any())).called(1);
      expect(
        sentBody['pickupDateTime'],
        expectedLocal.toUtc().toIso8601String(),
      );
    },
  );

  testWidgets('opens the date picker for a past ride without asserting', (
    tester,
  ) async {
    // A ride well in the past: with firstDate = now the picker would assert
    // (initialDate < firstDate). The dialog must clamp the window around the
    // ride's own date so the picker opens.
    final past = DateTime.now().subtract(const Duration(days: 60));
    final ride = TestFixtures.ride(id: 'ride-past', pickupDateTime: past);

    await tester.pumpWidget(buildHost(ride));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-ride-pickup-datetime')));
    await tester.pumpAndSettle();

    // The date picker is open (no exception thrown during the tap).
    expect(tester.takeException(), isNull);
    expect(find.text('OK'), findsOneWidget);
  });
}
