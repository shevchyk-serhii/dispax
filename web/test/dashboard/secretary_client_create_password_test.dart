// Regression: adding a client from Manage Clients never worked — the backend
// CreateUserRequest requires a `password` field (temporary, forced change on
// first login), but the app's CreateUserRequest.toJson() did not send one, so
// POST /api/users always failed with 400 "missing at 'password'". On top of
// that the panel swallowed mutation errors whenever the list was non-empty,
// so the failure was completely silent. The dialog must now send a
// policy-compliant temporary password, and a failed mutation must surface as
// a SnackBar.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/client/client_bloc.dart';
import 'package:dispax/blocs/client/client_event.dart';
import 'package:dispax/blocs/client/client_state.dart';
import 'package:dispax/dashboard/secretary/widgets/client_list_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/models/user_requests.dart';
import 'package:dispax/utils/temp_password.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClientBloc extends MockBloc<ClientEvent, ClientState>
    implements ClientBloc {}

class _FakeClientEvent extends Fake implements ClientEvent {}

Person _client() => Person(
  id: 'client-1',
  name: 'Anna Klein',
  email: 'anna@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeClientEvent()));

  late _MockClientBloc clientBloc;

  setUp(() {
    clientBloc = _MockClientBloc();
    when(() => clientBloc.state).thenReturn(ClientState.loaded([_client()]));
    when(() => clientBloc.add(any())).thenAnswer((_) {});
  });

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locale: const Locale('en'),
    home: BlocProvider<ClientBloc>.value(
      value: clientBloc,
      child: const ClientListPanel(),
    ),
  );

  Future<void> openCreateDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  test('CreateUserRequest.toJson carries the password for the backend', () {
    final json = const CreateUserRequest(
      name: 'New Client',
      email: 'new@example.com',
      password: 'Temp1234',
    ).toJson();

    expect(
      json['password'],
      'Temp1234',
      reason: 'POST /api/users rejects a body without a password',
    );
  });

  testWidgets('create dialog is pre-filled with a policy-compliant password', (
    tester,
  ) async {
    await openCreateDialog(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final passwordField = find.widgetWithText(
      TextFormField,
      l10n.temporaryPassword,
    );
    expect(passwordField, findsOneWidget);

    final prefilled = tester
        .widget<TextFormField>(passwordField)
        .controller!
        .text;
    expect(
      isValidTempPassword(prefilled),
      isTrue,
      reason: 'the pre-filled temporary password must pass the backend policy',
    );
  });

  testWidgets('submitting the create dialog sends the temporary password', (
    tester,
  ) async {
    await openCreateDialog(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.name),
      'New Client',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.email),
      'new@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, l10n.addButton));
    await tester.pumpAndSettle();

    final captured = verify(
      () => clientBloc.add(captureAny()),
    ).captured.whereType<ClientCreateRequested>().toList();

    expect(captured, hasLength(1));
    final request = captured.single.request;
    expect(request.name, 'New Client');
    expect(request.email, 'new@example.com');
    expect(
      isValidTempPassword(request.password),
      isTrue,
      reason: 'the dispatched request must carry a policy-compliant password',
    );
    expect(request.toJson()['password'], request.password);
  });

  testWidgets('a weak manually-edited password blocks submission', (
    tester,
  ) async {
    await openCreateDialog(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.name),
      'New Client',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.email),
      'new@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.temporaryPassword),
      'weak',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, l10n.addButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.tempPasswordRules), findsOneWidget);
    final captured = verify(
      () => clientBloc.add(captureAny()),
    ).captured.whereType<ClientCreateRequested>().toList();
    expect(captured, isEmpty);
  });

  testWidgets('a failed mutation surfaces as a SnackBar (not silent)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final loaded = ClientState.loaded([_client()]);
    final failed = loaded.copyWith(
      status: ClientStateStatus.error,
      errorMessage: 'Failed to create client',
    );
    final states = StreamController<ClientState>();
    whenListen(clientBloc, states.stream, initialState: loaded);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    states.add(failed);
    await tester.pumpAndSettle();

    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: 'a create/update/deactivate failure must be visible to the user',
    );
    await states.close();
  });
}
