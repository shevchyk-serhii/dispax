// Widget tests for the client picker in the ride edit dialog
// (NavigationUtils.navigateToEditRide).
//
// A dispatcher can reassign the ride to a different client. The PUT body
// carries `clientId` ONLY when a different client was picked — absent means
// "keep the current client" on the backend, and re-sending the dialog's
// snapshot could clobber a concurrent reassignment. Non-dispatchers never see
// the picker (they also lack access to GET /users/clients).

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/navigation_utils.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/ride_management/widgets/client_autocomplete_field.dart';
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

  final currentClient = TestFixtures.person(
    id: 'client-1',
    name: 'Test Client',
    email: 'test.client@example.com',
  );
  final otherClient = TestFixtures.person(
    id: 'client-2',
    name: 'Other Client',
    email: 'other.client@example.com',
  );

  void authenticateAs(Person user) {
    when(() => authBloc.state).thenReturn(AuthState.authenticated(user));
  }

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();

    when(() => authBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.apiClient).thenReturn(apiClient);
    authenticateAs(
      TestFixtures.person(
        id: 'dispatcher-1',
        name: 'Dispatcher Iryna',
        role: PersonRole.dispatcher,
      ),
    );
    when(() => apiClient.get('/users/clients')).thenAnswer(
      (_) async => http.Response(
        jsonEncode([currentClient.toJson(), otherClient.toJson()]),
        200,
      ),
    );
  });

  Widget buildHost(Ride ride) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // AuthBloc must live above the root navigator so the dialog can read it —
    // mirrors AppRoot (see edit_ride_dialog_clear_fields_test.dart).
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

  Future<AppLocalizations> openDialog(WidgetTester tester, Ride ride) async {
    await tester.pumpWidget(buildHost(ride));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(TextField).first))!;
  }

  Future<void> save(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(find.text(l10n.save));
    // The save handler shows a spinner while awaiting the PUT, so pumpAndSettle
    // would spin forever; pump a few discrete frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('picking a different client sends clientId in the PUT body', (
    tester,
  ) async {
    final ride = TestFixtures.ride(id: 'ride-1');

    late Map<String, dynamic> sentBody;
    when(() => apiClient.put(any(), any())).thenAnswer((invocation) async {
      sentBody = invocation.positionalArguments[1] as Map<String, dynamic>;
      return http.Response(jsonEncode(ride.toJson()), 200);
    });

    final l10n = await openDialog(tester, ride);

    // The picker is pre-filled with the ride's current client.
    expect(find.byType(ClientAutocompleteField), findsOneWidget);
    expect(find.text('Test Client'), findsOneWidget);

    // Search and pick the other client from the options list.
    await tester.enterText(
      find.widgetWithText(TextField, 'Client Name'),
      'Other',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other Client').last);
    await tester.pumpAndSettle();

    await save(tester, l10n);

    verify(() => apiClient.put('/rides/ride-1', any())).called(1);
    expect(sentBody['clientId'], 'client-2');
  });

  testWidgets('an edit that keeps the client omits clientId from the body', (
    tester,
  ) async {
    final ride = TestFixtures.ride(id: 'ride-2');

    late Map<String, dynamic> sentBody;
    when(() => apiClient.put(any(), any())).thenAnswer((invocation) async {
      sentBody = invocation.positionalArguments[1] as Map<String, dynamic>;
      return http.Response(jsonEncode(ride.toJson()), 200);
    });

    final l10n = await openDialog(tester, ride);

    // Edit an unrelated field only.
    await tester.enterText(
      find.widgetWithText(TextField, l10n.notesOptionalLabel),
      'ring the bell',
    );

    await save(tester, l10n);

    verify(() => apiClient.put('/rides/ride-2', any())).called(1);
    expect(sentBody.containsKey('clientId'), isFalse);
  });

  testWidgets('clearing the picker omits clientId (keep the client)', (
    tester,
  ) async {
    final ride = TestFixtures.ride(id: 'ride-3');

    late Map<String, dynamic> sentBody;
    when(() => apiClient.put(any(), any())).thenAnswer((invocation) async {
      sentBody = invocation.positionalArguments[1] as Map<String, dynamic>;
      return http.Response(jsonEncode(ride.toJson()), 200);
    });

    final l10n = await openDialog(tester, ride);

    // Clear the pre-selected client via the suffix clear button.
    await tester.tap(
      find.descendant(
        of: find.byType(ClientAutocompleteField),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    await save(tester, l10n);

    verify(() => apiClient.put('/rides/ride-3', any())).called(1);
    expect(sentBody.containsKey('clientId'), isFalse);
  });

  testWidgets('a driver sees no client picker and clients are never fetched', (
    tester,
  ) async {
    authenticateAs(TestFixtures.driver(id: 'driver-1'));
    final ride = TestFixtures.ride(id: 'ride-4');

    await openDialog(tester, ride);

    expect(find.byType(ClientAutocompleteField), findsNothing);
    verifyNever(() => apiClient.get('/users/clients'));
  });
}
