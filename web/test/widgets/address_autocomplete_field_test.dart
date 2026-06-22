import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/widgets/address_autocomplete_field.dart';
import 'package:dispax/modules/ride_management/models/client_address.dart';

// Three fixed suggestions used across all tests.
final _now = DateTime(2026, 1, 1);

ClientAddress _addr(String address, String label) => ClientAddress(
  id: address,
  clientId: 'client-1',
  label: label,
  address: address,
  useCount: 1,
  createdAt: _now,
  updatedAt: _now,
);

// Convenience: pump the widget inside a MaterialApp that provides the overlay
// (required by Autocomplete).
Future<void> _pump(
  WidgetTester tester, {
  required List<ClientAddress> suggestions,
  String? excludeAddress,
  String initialValue = '',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AddressAutocompleteField(
          labelText: 'Address',
          hintText: 'Type address',
          prefixIconData: Icons.location_on,
          initialValue: initialValue,
          onChanged: (_) {},
          suggestions: suggestions,
          excludeAddress: excludeAddress,
        ),
      ),
    ),
  );
}

// Taps the text field (gives it focus) so the Autocomplete overlay appears,
// then pumps to let the overlay render.
Future<void> _focusField(WidgetTester tester) async {
  await tester.tap(find.byType(TextFormField));
  await tester.pump();
}

void main() {
  final airport = _addr('Munich Airport T1', 'Airport');
  final hotel = _addr('Grand Hotel Munich', 'Hotel');
  final office = _addr('Dispax HQ', 'Office');
  final allSuggestions = [airport, hotel, office];

  group('AddressAutocompleteField — excludeAddress filter', () {
    testWidgets('without excludeAddress all suggestions appear when focused', (
      tester,
    ) async {
      await _pump(tester, suggestions: allSuggestions);
      await _focusField(tester);

      expect(find.text('Munich Airport T1'), findsOneWidget);
      expect(find.text('Grand Hotel Munich'), findsOneWidget);
      expect(find.text('Dispax HQ'), findsOneWidget);
    });

    testWidgets(
      'excluded suggestion is absent from the dropdown on empty query',
      (tester) async {
        await _pump(
          tester,
          suggestions: allSuggestions,
          excludeAddress: 'Munich Airport T1',
        );
        await _focusField(tester);

        // The excluded address must not be rendered.
        expect(find.text('Munich Airport T1'), findsNothing);
        // The other two must still appear.
        expect(find.text('Grand Hotel Munich'), findsOneWidget);
        expect(find.text('Dispax HQ'), findsOneWidget);
      },
    );

    testWidgets('excluded suggestion is absent when query matches it exactly', (
      tester,
    ) async {
      await _pump(
        tester,
        suggestions: allSuggestions,
        excludeAddress: 'Munich Airport T1',
      );
      await _focusField(tester);

      // Type the excluded address as the query.
      await tester.enterText(find.byType(TextFormField), 'Munich Airport');
      await tester.pump();

      expect(find.text('Munich Airport T1'), findsNothing);
    });

    testWidgets('exclusion is case-insensitive', (tester) async {
      await _pump(
        tester,
        suggestions: allSuggestions,
        // Different case from the stored address.
        excludeAddress: 'MUNICH AIRPORT T1',
      );
      await _focusField(tester);

      expect(find.text('Munich Airport T1'), findsNothing);
      expect(find.text('Grand Hotel Munich'), findsOneWidget);
    });

    testWidgets('exclusion trims surrounding whitespace', (tester) async {
      await _pump(
        tester,
        suggestions: allSuggestions,
        excludeAddress: '  Munich Airport T1  ',
      );
      await _focusField(tester);

      expect(find.text('Munich Airport T1'), findsNothing);
      expect(find.text('Grand Hotel Munich'), findsOneWidget);
    });

    testWidgets('null excludeAddress shows all suggestions', (tester) async {
      await _pump(tester, suggestions: allSuggestions, excludeAddress: null);
      await _focusField(tester);

      expect(find.text('Munich Airport T1'), findsOneWidget);
      expect(find.text('Grand Hotel Munich'), findsOneWidget);
      expect(find.text('Dispax HQ'), findsOneWidget);
    });

    testWidgets('empty string excludeAddress shows all suggestions', (
      tester,
    ) async {
      await _pump(tester, suggestions: allSuggestions, excludeAddress: '');
      await _focusField(tester);

      expect(find.text('Munich Airport T1'), findsOneWidget);
      expect(find.text('Grand Hotel Munich'), findsOneWidget);
      expect(find.text('Dispax HQ'), findsOneWidget);
    });
  });
}
