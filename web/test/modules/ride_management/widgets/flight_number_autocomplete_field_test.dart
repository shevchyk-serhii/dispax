// Widget tests for FlightNumberAutocompleteField: the board is fetched lazily
// on first focus (per date+direction key), suggestions filter by normalized
// contains-match, selection fires onChanged, and the field degrades to a plain
// input when no service is available.

import 'package:dispax/modules/flight_management/models/muc_flight.dart';
import 'package:dispax/modules/flight_management/services/arrivals_board_service.dart';
import 'package:dispax/modules/ride_management/widgets/flight_number_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockArrivalsBoardService extends Mock implements ArrivalsBoardService {}

void main() {
  late _MockArrivalsBoardService service;

  final flights = [
    MucFlight(
      flightNumber: 'LH123',
      status: 'landed',
      airline: 'Lufthansa',
      origin: 'FRA',
      estimatedTime: DateTime(2026, 7, 10, 14, 35),
    ),
    const MucFlight(flightNumber: 'LH456', status: 'scheduled'),
    const MucFlight(flightNumber: 'BA789', status: 'scheduled'),
  ];

  setUp(() {
    service = _MockArrivalsBoardService();
    when(
      () => service.getArrivals(
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    ).thenAnswer((_) async => flights);
  });

  Future<void> pump(
    WidgetTester tester, {
    required ValueChanged<String> onChanged,
    String value = '',
    bool isArrival = true,
    DateTime? flightDate,
    ArrivalsBoardService? fieldService,
    bool useMock = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlightNumberAutocompleteField(
            value: value,
            onChanged: onChanged,
            labelText: 'Flight number',
            hintText: 'e.g. LH429',
            prefixIconData: Icons.flight_land,
            isArrival: isArrival,
            flightDate: flightDate,
            service: useMock ? (fieldService ?? service) : fieldService,
          ),
        ),
      ),
    );
  }

  testWidgets('does not fetch the board before the field is focused', (
    tester,
  ) async {
    await pump(tester, onChanged: (_) {});
    await tester.pump();

    verifyNever(
      () => service.getArrivals(
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    );
  });

  testWidgets('fetches once on focus with the field date and direction', (
    tester,
  ) async {
    await pump(
      tester,
      onChanged: (_) {},
      flightDate: DateTime(2026, 7, 10, 14, 30),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    // A second focus/tap must not refetch — the board is cached per key.
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();

    verify(
      () => service.getArrivals(date: '2026-07-10', isArrival: true),
    ).called(1);
  });

  testWidgets('typing filters suggestions to matching flight numbers', (
    tester,
  ) async {
    await pump(tester, onChanged: (_) {});

    // Focus → fetch resolves; then type to open the options overlay.
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'lh');
    await tester.pump();

    // Input is upper-cased; only LH flights are suggested.
    expect(find.text('LH'), findsOneWidget);
    expect(find.text('LH123'), findsOneWidget);
    expect(find.text('LH456'), findsOneWidget);
    expect(find.text('BA789'), findsNothing);
    // Suggestion row carries airline · origin and the estimated time.
    expect(find.text('Lufthansa · FRA'), findsOneWidget);
    expect(find.text('14:35'), findsOneWidget);
  });

  testWidgets('tapping a suggestion fires onChanged with the flight number', (
    tester,
  ) async {
    String last = '';
    await pump(tester, onChanged: (v) => last = v);

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'LH1');
    await tester.pump();

    await tester.tap(find.text('LH123'));
    await tester.pump();

    expect(last, 'LH123');
  });

  testWidgets('switching direction refetches the board for the new key', (
    tester,
  ) async {
    final date = DateTime(2026, 7, 10);
    await pump(tester, onChanged: (_) {}, flightDate: date, isArrival: true);

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    verify(
      () => service.getArrivals(date: '2026-07-10', isArrival: true),
    ).called(1);

    // Rebuild as a departure field while still focused → immediate refetch.
    await pump(tester, onChanged: (_) {}, flightDate: date, isArrival: false);
    await tester.pumpAndSettle();

    verify(
      () => service.getArrivals(date: '2026-07-10', isArrival: false),
    ).called(1);
  });

  testWidgets('degrades to a plain input when no service is available', (
    tester,
  ) async {
    // No service passed and the singleton is not configured in tests.
    String last = '';
    await pump(tester, onChanged: (v) => last = v, useMock: false);

    await tester.enterText(find.byType(TextFormField), 'lh429');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('LH429'), findsOneWidget);
    expect(last, 'LH429');
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('the clear button empties the field and fires onChanged', (
    tester,
  ) async {
    String last = 'unset';
    await pump(tester, onChanged: (v) => last = v, value: 'LH123');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(last, '');
    expect(find.text('LH123'), findsNothing);
  });

  testWidgets('an external value change syncs into the unfocused field', (
    tester,
  ) async {
    await pump(tester, onChanged: (_) {}, value: '');

    // Edit-ride prefill: the parent pushes a new value from the bloc.
    await pump(tester, onChanged: (_) {}, value: 'BA789');
    await tester.pump();

    expect(find.text('BA789'), findsOneWidget);
  });
}
