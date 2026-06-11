import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/billing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  // One invoice with a reminder already sent, one without — so a single render
  // exercises both the "reminded" and "not reminded" branches of the card.
  Map<String, dynamic> invoiceJson({
    required String id,
    required String number,
    required String clientCompanyId,
    String? reminderSentAt,
  }) =>
      {
        'id': id,
        'number': number,
        'clientCompanyId': clientCompanyId,
        'taxiCompanyId': 'tc-1',
        'status': 'Sent',
        'periodFrom': '2026-01-01',
        'periodTo': '2026-01-31',
        'subtotalAmount': 100.0,
        'taxRate': 19.0,
        'taxAmount': 19.0,
        'totalAmount': 119.0,
        'currency': 'EUR',
        'sentAt': '2026-01-10T09:00:00.000Z',
        if (reminderSentAt != null) 'reminderSentAt': reminderSentAt,
        'items': const [],
        'createdAt': '2026-01-01T12:00:00.000Z',
        'updatedAt': '2026-01-02T08:00:00.000Z',
      };

  const companiesBody = '['
      '{"id":"cc-reminded","name":"BMW AG","taxiCompanyId":"tc-1"},'
      '{"id":"cc-plain","name":"Siemens AG","taxiCompanyId":"tc-1"}'
      ']';

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);

    final byId = {
      'inv-reminded': invoiceJson(
        id: 'inv-reminded',
        number: 'INV-2026-0001',
        clientCompanyId: 'cc-reminded',
        reminderSentAt: '2026-03-05T08:00:00.000Z',
      ),
      'inv-plain': invoiceJson(
        id: 'inv-plain',
        number: 'INV-2026-0002',
        clientCompanyId: 'cc-plain',
      ),
    };
    final invoicesBody = jsonEncode(byId.values.toList());

    // Endpoints carry query params (e.g. /billing/invoices?limit=50&offset=0),
    // so route by path prefix rather than an exact string.
    when(() => apiClient.get(any())).thenAnswer((invocation) async {
      final endpoint = invocation.positionalArguments.first as String;
      // Single-invoice fetch (detail sheet refresh): /billing/invoices/<id>.
      final detail = RegExp(r'^/billing/invoices/([^/?]+)').firstMatch(endpoint);
      if (detail != null) {
        final inv = byId[detail.group(1)];
        if (inv != null) return http.Response(jsonEncode(inv), 200);
        return http.Response('{}', 404);
      }
      if (endpoint.startsWith('/billing/invoices')) {
        return http.Response(invoicesBody, 200);
      }
      if (endpoint.startsWith('/billing/companies')) {
        return http.Response(companiesBody, 200);
      }
      // Rides tab and anything else: empty list keeps the screen happy.
      return http.Response('[]', 200);
    });
  });

  Widget pumpApp() => MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const Scaffold(body: BillingScreen()),
        ),
      );

  testWidgets('reminded invoice card shows the reminder bell, plain one does not',
      (tester) async {
    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    // Both invoices rendered.
    expect(find.text('INV-2026-0001'), findsOneWidget);
    expect(find.text('INV-2026-0002'), findsOneWidget);

    // Exactly one reminder indicator — on the reminded invoice only.
    final bells = find.byIcon(Icons.notifications_active);
    expect(bells, findsOneWidget);

    // The bell carries the German reminder tooltip.
    expect(
      find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'Zahlungserinnerung versendet',
      ),
      findsOneWidget,
    );

    // And it is tinted with the info colour, not a status colour.
    final bellIcon = tester.widget<Icon>(bells);
    expect(bellIcon.color, AppColors.info);
  });

  testWidgets('invoice detail sheet shows the "Erinnert" badge for a reminded invoice',
      (tester) async {
    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    // Open the reminded invoice's detail sheet.
    await tester.tap(find.text('INV-2026-0001'));
    await tester.pumpAndSettle();

    // The reminder badge renders the German label with the sent date (dd.MM.yyyy).
    expect(find.text('Erinnert 05.03.2026'), findsOneWidget);
  });

  testWidgets('invoice detail sheet has no reminder badge when not reminded',
      (tester) async {
    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('INV-2026-0002'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Erinnert'), findsNothing);
  });
}
