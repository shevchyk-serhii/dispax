// Regression: the billing feature mixed two currency formats — the invoice
// list/tiles used fmtEur (German locale, "1.234,56 €" style) while the detail
// sheet's line items and _TotalRow hardcoded the period format
// '€${x.toStringAsFixed(2)}'. One invoice showed two different formats.
// Everything must go through fmtEur.

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/dashboard/superadmin/widgets/billing_widgets.dart'
    show fmtEur;
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/billing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  final invoice = {
    'id': 'inv-1',
    'number': 'INV-2026-0001',
    'clientCompanyId': 'cc-1',
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
    'items': [
      {
        'id': 'item-1',
        'invoiceId': 'inv-1',
        'description': 'Airport transfer',
        'quantity': 1.0,
        'unitPrice': 1234.56,
        'total': 1234.56,
        'createdAt': '2026-01-01T12:00:00.000Z',
      },
    ],
    'createdAt': '2026-01-01T12:00:00.000Z',
    'updatedAt': '2026-01-02T08:00:00.000Z',
  };

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);

    when(() => apiClient.get(any())).thenAnswer((invocation) async {
      final endpoint = invocation.positionalArguments.first as String;
      if (RegExp(r'^/billing/invoices/[^/?]+').hasMatch(endpoint)) {
        return http.Response(jsonEncode(invoice), 200);
      }
      if (endpoint.startsWith('/billing/invoices')) {
        return http.Response(jsonEncode([invoice]), 200);
      }
      if (endpoint.startsWith('/billing/companies')) {
        return http.Response(
          '[{"id":"cc-1","name":"BMW AG","taxiCompanyId":"tc-1"}]',
          200,
        );
      }
      return http.Response('[]', 200);
    });
  });

  Widget pumpApp() => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('de'),
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: const Scaffold(body: BillingScreen()),
    ),
  );

  testWidgets('invoice detail sheet formats line items and totals with '
      'fmtEur, matching the list', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    // Open the invoice's detail sheet.
    await tester.tap(find.text('INV-2026-0001'));
    await tester.pumpAndSettle();

    // Line item and total rows use the shared German formatter…
    expect(find.text(fmtEur(1234.56)), findsOneWidget); // line item
    expect(find.text(fmtEur(100.0)), findsOneWidget); // subtotal row
    expect(find.text(fmtEur(19.0)), findsOneWidget); // VAT row
    // …and the hardcoded period format is gone.
    expect(find.textContaining('€1234.56'), findsNothing);
    expect(find.textContaining('€100.00'), findsNothing);
  });
}
