// Widget test for the ride edit dialog (NavigationUtils.navigateToEditRide).
//
// Coverage gap this closes: the dialog used to send notes/flightNumber only
// when non-empty, so a dispatcher could never *clear* them — the backend treats
// an absent field as "leave unchanged". The fix makes the dialog always send
// both fields (empty string = clear). This test pins that the PUT body carries
// empty strings when the user wipes the fields, so the clearing path can't
// silently regress back to omitting them.

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

  Widget buildHost(Ride ride) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // The dialog is shown on the root navigator (above `home`), so provide
    // AuthBloc above the navigator via `builder` — mirroring AppRoot, where the
    // bloc lives at the top. A BlocProvider inside `home` would not be visible
    // to the dialog's context (ProviderNotFoundException in _save).
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
    'clearing flight number and notes sends empty strings in the PUT body',
    (tester) async {
      final ride = TestFixtures.ride(
        id: 'ride-9',
        flightNumber: 'LH100',
        isAirportTransfer: true,
        isArrival: true,
      ).copyWith(notes: 'call on arrival');

      // Echo the body back so Ride.fromJson succeeds on the 200 response.
      late Map<String, dynamic> sentBody;
      when(() => apiClient.put(any(), any())).thenAnswer((invocation) async {
        sentBody = invocation.positionalArguments[1] as Map<String, dynamic>;
        return http.Response(jsonEncode(ride.toJson()), 200);
      });

      await tester.pumpWidget(buildHost(ride));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TextField).first),
      )!;

      // Wipe both optional fields, targeting them by their label.
      await tester.enterText(
        find.widgetWithText(TextField, l10n.flightNumberOptionalLabel),
        '',
      );
      await tester.enterText(
        find.widgetWithText(TextField, l10n.notesOptionalLabel),
        '',
      );

      expect(find.text(l10n.save), findsOneWidget);
      await tester.tap(find.text(l10n.save));
      // The save handler shows a CircularProgressIndicator while awaiting the PUT,
      // so pumpAndSettle would spin forever; pump a few discrete frames instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      verify(() => apiClient.put('/rides/ride-9', any())).called(1);
      // The clearing fix: both fields are present and empty (not omitted).
      expect(sentBody['flightNumber'], '');
      expect(sentBody['notes'], '');
      // Clearing the flight number does NOT un-airport the ride — the toggle stays on.
      expect(sentBody['isAirportTransfer'], true);
    },
  );

  testWidgets('toggling airport OFF sends isAirportTransfer false', (
    tester,
  ) async {
    final ride = TestFixtures.ride(
      id: 'ride-off',
      flightNumber: 'LH100',
      isAirportTransfer: true,
      isArrival: true,
    );

    late Map<String, dynamic> sentBody;
    when(() => apiClient.put(any(), any())).thenAnswer((invocation) async {
      sentBody = invocation.positionalArguments[1] as Map<String, dynamic>;
      return http.Response(jsonEncode(ride.toJson()), 200);
    });

    await tester.pumpWidget(buildHost(ride));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Flip the airport switch off.
    await tester.tap(find.byKey(const Key('edit-ride-airport-toggle')));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(TextField).first),
    )!;
    await tester.tap(find.text(l10n.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    verify(() => apiClient.put('/rides/ride-off', any())).called(1);
    expect(sentBody['isAirportTransfer'], false);
  });

  testWidgets(
    'toggling airport ON for a plain ride sends isAirportTransfer true',
    (tester) async {
      final ride = TestFixtures.ride(id: 'ride-on'); // not an airport transfer

      late Map<String, dynamic> sentBody;
      when(() => apiClient.put(any(), any())).thenAnswer((invocation) async {
        sentBody = invocation.positionalArguments[1] as Map<String, dynamic>;
        return http.Response(jsonEncode(ride.toJson()), 200);
      });

      await tester.pumpWidget(buildHost(ride));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Flip the airport switch on (no flight number entered — that's allowed).
      await tester.tap(find.byKey(const Key('edit-ride-airport-toggle')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TextField).first),
      )!;
      await tester.tap(find.text(l10n.save));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      verify(() => apiClient.put('/rides/ride-on', any())).called(1);
      expect(sentBody['isAirportTransfer'], true);
      // Flight number is sent (empty) — airport without a flight is valid.
      expect(sentBody['flightNumber'], '');
    },
  );
}
