// Widget tests for the arrivals-board live search filter: typing narrows the
// already-loaded board list client-side (no extra network), clearing restores
// all rows, and submit still performs the exact per-flight lookup.

import 'package:dispax/dashboard/dispatcher/arrivals_board_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/flight_management/models/muc_flight.dart';
import 'package:dispax/modules/flight_management/services/arrivals_board_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockArrivalsBoardService extends Mock implements ArrivalsBoardService {}

void main() {
  late _MockArrivalsBoardService service;

  const flights = [
    MucFlight(
      flightNumber: 'LH123',
      status: 'landed',
      airline: 'Lufthansa',
      origin: 'FRA',
    ),
    MucFlight(flightNumber: 'LH456', status: 'scheduled', origin: 'JFK'),
    // NOTE: origin deliberately not "LHR" — the filter also matches the origin
    // airport, and "LHR".contains("LH") would keep this row in the LH tests.
    MucFlight(
      flightNumber: 'BA789',
      status: 'scheduled',
      airline: 'British Airways',
      origin: 'MAD',
    ),
  ];

  setUp(() {
    service = _MockArrivalsBoardService();
    when(
      () => service.getArrivals(
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    ).thenAnswer((_) async => flights);
    // Rows lazily look up their gate; irrelevant here.
    when(
      () => service.lookupFlight(
        flightNumber: any(named: 'flightNumber'),
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    ).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArrivalsBoardScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('typing a flight-number prefix narrows the board list', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('LH123'), findsOneWidget);
    expect(find.text('BA789'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'LH');
    await tester.pumpAndSettle();

    expect(find.text('LH123'), findsOneWidget);
    expect(find.text('LH456'), findsOneWidget);
    expect(find.text('BA789'), findsNothing);
    // The narrowing is local — no per-keystroke lookup calls.
    verifyNever(
      () => service.lookupFlight(
        flightNumber: 'LH',
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    );
  });

  testWidgets('the filter also matches airline and origin', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'british');
    await tester.pumpAndSettle();

    expect(find.text('BA789'), findsOneWidget);
    expect(find.text('LH123'), findsNothing);
  });

  testWidgets('clearing the filter restores all rows', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'LH');
    await tester.pumpAndSettle();
    expect(find.text('BA789'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.text('LH123'), findsOneWidget);
    expect(find.text('LH456'), findsOneWidget);
    expect(find.text('BA789'), findsOneWidget);
  });

  testWidgets('a filter with no matches shows the empty state', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'ZZ999');
    await tester.pumpAndSettle();

    expect(find.text('LH123'), findsNothing);
    // The en fallback of noArrivalsFound.
    expect(find.textContaining('No arrivals'), findsOneWidget);
  });

  testWidgets('submit still performs the exact single-flight lookup', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'LH123');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    verify(
      () => service.lookupFlight(
        flightNumber: 'LH123',
        date: any(named: 'date'),
        isArrival: true,
      ),
    ).called(greaterThanOrEqualTo(1));
  });
}
