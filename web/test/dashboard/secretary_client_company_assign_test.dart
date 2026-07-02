// Dispatcher/secretary can assign a client to a client company from the
// Manage Clients list: the edit dialog exposes a company dropdown (fed by
// ClientCompanyService) and sends the tri-state clientCompanyId in
// UpdateUserRequest ('' clears the link, a UUID sets it, absent = unchanged).
// The client card shows the resolved company name.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/client/client_bloc.dart';
import 'package:dispax/blocs/client/client_event.dart';
import 'package:dispax/blocs/client/client_state.dart';
import 'package:dispax/dashboard/secretary/widgets/client_list_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/billing/models/client_company.dart';
import 'package:dispax/modules/billing/services/client_company_service.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClientBloc extends MockBloc<ClientEvent, ClientState>
    implements ClientBloc {}

class _FakeClientEvent extends Fake implements ClientEvent {}

class _MockClientCompanyService extends Mock implements ClientCompanyService {}

const _bmw = ClientCompany(id: 'cc-1', name: 'BMW AG', taxiCompanyId: 't-1');
const _siemens = ClientCompany(
  id: 'cc-2',
  name: 'Siemens',
  taxiCompanyId: 't-1',
);

Person _linkedClient() => Person(
  id: 'client-1',
  name: 'Herr Schneider',
  email: 'schneider@bmw.de',
  role: PersonRole.client,
  companyId: 't-1',
  clientCompanyId: 'cc-1',
);

Person _unlinkedClient() => Person(
  id: 'client-2',
  name: 'Mark',
  email: 'mark@example.com',
  role: PersonRole.client,
  companyId: 't-1',
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeClientEvent()));

  late _MockClientBloc clientBloc;
  late _MockClientCompanyService companyService;

  setUp(() {
    clientBloc = _MockClientBloc();
    companyService = _MockClientCompanyService();
    when(
      () => clientBloc.state,
    ).thenReturn(ClientState.loaded([_linkedClient()]));
    when(() => clientBloc.add(any())).thenAnswer((_) {});
    when(
      () => companyService.getCompanies(),
    ).thenAnswer((_) async => [_bmw, _siemens]);
  });

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locale: const Locale('en'),
    home: Scaffold(
      body: BlocProvider<ClientBloc>.value(
        value: clientBloc,
        child: ClientListPanel(companyService: companyService),
      ),
    ),
  );

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openEditDialog(
    WidgetTester tester,
    AppLocalizations l10n,
  ) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editAction).last);
    await tester.pumpAndSettle();
  }

  List<ClientUpdateRequested> capturedUpdates() => verify(
    () => clientBloc.add(captureAny()),
  ).captured.whereType<ClientUpdateRequested>().toList();

  testWidgets('client card shows the linked company name', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('BMW AG'), findsOneWidget);
  });

  testWidgets('card shows no company line for an unlinked client', (
    tester,
  ) async {
    useLargeSurface(tester);
    when(
      () => clientBloc.state,
    ).thenReturn(ClientState.loaded([_unlinkedClient()]));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('BMW AG'), findsNothing);
    expect(find.text('Siemens'), findsNothing);
  });

  testWidgets('edit dialog assigns another company and sends its id', (
    tester,
  ) async {
    useLargeSurface(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await openEditDialog(tester, l10n);

    // The dropdown is present and preselects the client's current company.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siemens').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, l10n.save));
    await tester.pumpAndSettle();

    final captured = capturedUpdates();
    expect(captured, hasLength(1));
    expect(captured.single.clientId, 'client-1');
    expect(
      captured.single.request.clientCompanyId,
      'cc-2',
      reason: 'the selected company must reach the update request',
    );
  });

  testWidgets('choosing "No company" sends an empty string (clear)', (
    tester,
  ) async {
    useLargeSurface(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await openEditDialog(tester, l10n);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.clientCompanyNone).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, l10n.save));
    await tester.pumpAndSettle();

    final captured = capturedUpdates();
    expect(captured, hasLength(1));
    expect(
      captured.single.request.clientCompanyId,
      '',
      reason: 'empty string is the backend contract for clearing the link',
    );
  });

  testWidgets(
    'when companies fail to load the dialog hides the field and omits it',
    (tester) async {
      useLargeSurface(tester);
      when(
        () => companyService.getCompanies(),
      ).thenAnswer((_) async => throw Exception('boom'));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await openEditDialog(tester, l10n);

      // No dropdown — a failed load must never lead to a silent clear.
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, l10n.save));
      await tester.pumpAndSettle();

      final captured = capturedUpdates();
      expect(captured, hasLength(1));
      expect(
        captured.single.request.clientCompanyId,
        isNull,
        reason: 'absent field means "leave unchanged" on the backend',
      );
      expect(
        captured.single.request.toJson().containsKey('clientCompanyId'),
        isFalse,
      );
    },
  );

  test('Person.fromJson parses clientCompanyId (flat and object forms)', () {
    final flat = Person.fromJson({
      'id': 'p-1',
      'name': 'X',
      'email': 'x@example.com',
      'role': 'CLIENT',
      'clientCompanyId': 'cc-9',
    });
    final wrapped = Person.fromJson({
      'id': 'p-2',
      'name': 'Y',
      'email': 'y@example.com',
      'role': 'CLIENT',
      'clientCompanyId': {'value': 'cc-9'},
    });
    final absent = Person.fromJson({
      'id': 'p-3',
      'name': 'Z',
      'email': 'z@example.com',
      'role': 'CLIENT',
    });
    expect(flat.clientCompanyId, 'cc-9');
    expect(wrapped.clientCompanyId, 'cc-9');
    expect(absent.clientCompanyId, isNull);
  });
}
