// Widget tests for the secretary "Add Client" dialog (ClientListPanel ->
// _showCreateClientDialog).
//
// The dialog has three fields (name / email / phone) with inline validators and
// fires ClientCreateRequested on a valid submit. These tests pin the validation
// gating (empty name, empty email, email without "@" all block the event) and
// the happy path (event fired, phone trimmed / null when blank).

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/client/client_bloc.dart';
import 'package:dispax/blocs/client/client_event.dart';
import 'package:dispax/blocs/client/client_state.dart';
import 'package:dispax/dashboard/secretary/widgets/client_list_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeClientEvent extends Fake implements ClientEvent {}

class _MockClientBloc extends MockBloc<ClientEvent, ClientState>
    implements ClientBloc {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeClientEvent()));

  late _MockClientBloc bloc;

  setUp(() {
    bloc = _MockClientBloc();
    when(() => bloc.state).thenReturn(ClientState.initial());
  });

  Widget buildSubject() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<ClientBloc>.value(
      value: bloc,
      child: const ClientListPanel(),
    ),
  );

  // Open the Add Client dialog via the FAB.
  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  List<ClientCreateRequested> capturedCreates() => verify(
    () => bloc.add(captureAny()),
  ).captured.whereType<ClientCreateRequested>().toList();

  Finder fieldByLabel(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(TextFormField),
  );

  testWidgets('empty name blocks submit and shows error', (tester) async {
    await openDialog(tester);

    await tester.enterText(fieldByLabel('Email'), 'a@b.de');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pump();

    expect(find.text('Name is required'), findsOneWidget);
    expect(capturedCreates(), isEmpty);
  });

  testWidgets('empty email blocks submit and shows error', (tester) async {
    await openDialog(tester);

    await tester.enterText(fieldByLabel('Name'), 'Bruno');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(capturedCreates(), isEmpty);
  });

  testWidgets('email without "@" blocks submit', (tester) async {
    await openDialog(tester);

    await tester.enterText(fieldByLabel('Name'), 'Bruno');
    await tester.enterText(fieldByLabel('Email'), 'bruno.example.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pump();

    expect(find.text('Invalid email'), findsOneWidget);
    expect(capturedCreates(), isEmpty);
  });

  testWidgets('valid name + email with blank phone fires create, phone null', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.enterText(fieldByLabel('Name'), 'Bruno');
    // NOTE: the dialog uses an inline `contains('@')` check, not
    // Validators.email, so a dot-less domain like 'a@b' is accepted here even
    // though Validators.email would reject it. This pins the dialog's behaviour.
    await tester.enterText(fieldByLabel('Email'), 'bruno@example.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pump();

    final creates = capturedCreates();
    expect(creates, hasLength(1));
    expect(creates.single.request.name, 'Bruno');
    expect(creates.single.request.email, 'bruno@example.com');
    expect(creates.single.request.phone, isNull);
  });

  testWidgets('a filled phone is trimmed and forwarded', (tester) async {
    await openDialog(tester);

    await tester.enterText(fieldByLabel('Name'), 'Bruno');
    await tester.enterText(fieldByLabel('Email'), 'bruno@example.com');
    await tester.enterText(fieldByLabel('Phone (optional)'), '  +49123  ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pump();

    final creates = capturedCreates();
    expect(creates, hasLength(1));
    expect(creates.single.request.phone, '+49123');
  });
}
