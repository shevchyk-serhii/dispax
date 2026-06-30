// Widget tests for the flight-number field in AirportTransferCard:
// (1) it upper-cases as the user types, (2) it rejects a malformed number on
// validation but accepts a valid one (and accepts empty — the number is optional).

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/widgets/airport_transfer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required GlobalKey<FormState> formKey,
  required ValueChanged<String> onChanged,
  List<String> gates = const [],
  List<String> terminals = const [],
  String? selectedGate,
  String? selectedTerminal,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('de'),
      home: Scaffold(
        body: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: AirportTransferCard(
              isAirportTransfer: true,
              isArrival: false,
              flightNumber: '',
              onFlightNumberChanged: onChanged,
              selectedGate: selectedGate,
              selectedTerminal: selectedTerminal,
              gates: gates,
              terminals: terminals,
              onAirportTransferChanged: (_) {},
              onArrivalChanged: (_) {},
              onGateChanged: (_) {},
              onTerminalChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('upper-cases the flight number as the user types', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    String last = '';
    await _pump(tester, formKey: formKey, onChanged: (v) => last = v);

    final field = find.byType(TextFormField);
    await tester.enterText(field, 'lh429');
    await tester.pump();

    // The field shows the upper-cased value and the onChanged callback received it.
    expect(find.text('LH429'), findsOneWidget);
    expect(last, 'LH429');
  });

  testWidgets('flags a malformed flight number on validation', (tester) async {
    final formKey = GlobalKey<FormState>();
    await _pump(tester, formKey: formKey, onChanged: (_) {});

    await tester.enterText(find.byType(TextFormField), 'X1');
    formKey.currentState!.validate();
    await tester.pump();

    // German invalid-format message is shown.
    expect(
      find.text('Gültige Flugnummer eingeben, z.B. LH429'),
      findsOneWidget,
    );
  });

  testWidgets('an off-list selectedGate/terminal does not crash the dropdowns', (
    tester,
  ) async {
    // Regression: duplicating a tracked ride seeded the gate dropdown with a
    // real airport gate ("K14") that is not in the fixed option list, tripping
    // DropdownButtonFormField's "exactly one item" assertion. The card must
    // render (value falls back to null) instead of throwing.
    final formKey = GlobalKey<FormState>();
    await _pump(
      tester,
      formKey: formKey,
      onChanged: (_) {},
      gates: const ['A1', 'A2', 'A3'],
      terminals: const ['1', '2', '3'],
      selectedGate: 'K14',
      selectedTerminal: 'T2',
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AirportTransferCard), findsOneWidget);
  });

  testWidgets('accepts a valid number and an empty field', (tester) async {
    final formKey = GlobalKey<FormState>();
    await _pump(tester, formKey: formKey, onChanged: (_) {});

    // Valid number → form validates.
    await tester.enterText(find.byType(TextFormField), 'lh429');
    expect(formKey.currentState!.validate(), isTrue);
    await tester.pump();
    expect(find.text('Gültige Flugnummer eingeben, z.B. LH429'), findsNothing);

    // Empty → still valid (the number is optional).
    await tester.enterText(find.byType(TextFormField), '');
    expect(formKey.currentState!.validate(), isTrue);
  });
}
