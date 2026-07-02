// Widget test for the arrivals-board gate-on-tap flow: the board has no gate
// (it lives on the flight's detail page), so tapping a row must fire the
// per-flight lookup and surface the resolved gate in a bottom sheet.

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

  // A board row WITHOUT a gate (the board never carries one) ...
  final boardRow = MucFlight(
    flightNumber: 'LH2001',
    status: 'landed',
    terminal: 'T2',
    origin: 'DUS',
  );

  // ... and the same flight resolved via lookup, now WITH the gate.
  final withGate = MucFlight(
    flightNumber: 'LH2001',
    status: 'landed',
    terminal: 'T2',
    gate: 'G35',
    origin: 'DUS',
  );

  setUp(() {
    service = _MockArrivalsBoardService();
    when(
      () => service.getArrivals(
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    ).thenAnswer((_) async => [boardRow]);
    // Default: rows lazily look up their gate; individual tests override this.
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

  testWidgets('tapping a row looks up the flight and shows its gate', (
    tester,
  ) async {
    when(
      () => service.lookupFlight(
        flightNumber: any(named: 'flightNumber'),
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    ).thenAnswer((_) async => withGate);

    await pump(tester);

    // The board row is visible; tap it.
    expect(find.text('LH2001'), findsOneWidget);
    await tester.tap(find.text('LH2001'));
    await tester.pumpAndSettle();

    // The lookup was issued for this flight ...
    verify(
      () => service.lookupFlight(
        flightNumber: 'LH2001',
        date: any(named: 'date'),
        isArrival: true,
      ),
    ).called(greaterThanOrEqualTo(1));

    // ... and the resolved gate is shown (in the sheet; also inline in the row now).
    expect(find.textContaining('G35'), findsWidgets);
  });

  testWidgets('shows a "not published" fallback when no gate is available', (
    tester,
  ) async {
    when(
      () => service.lookupFlight(
        flightNumber: any(named: 'flightNumber'),
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    ).thenAnswer((_) async => null);

    await pump(tester);
    await tester.tap(find.text('LH2001'));
    await tester.pumpAndSettle();

    // German is not the default; en fallback text.
    expect(find.textContaining('not published'), findsOneWidget);
  });

  testWidgets('searching by flight number looks it up and shows its gate', (
    tester,
  ) async {
    when(
      () => service.lookupFlight(
        flightNumber: any(named: 'flightNumber'),
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    ).thenAnswer((_) async => withGate);

    await pump(tester);

    await tester.enterText(find.byType(TextField), 'LH2001');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    verify(
      () => service.lookupFlight(
        flightNumber: 'LH2001',
        date: any(named: 'date'),
        isArrival: true,
      ),
    ).called(greaterThanOrEqualTo(1));
    expect(find.textContaining('G35'), findsWidgets);
  });

  testWidgets('searching a non-existent flight shows a not-found snackbar', (
    tester,
  ) async {
    when(
      () => service.lookupFlight(
        flightNumber: any(named: 'flightNumber'),
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    ).thenAnswer((_) async => null);

    await pump(tester);

    await tester.enterText(find.byType(TextField), 'ZZ999');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(); // start the snackbar
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a board row lazily loads and shows its gate inline', (
    tester,
  ) async {
    // The row's lazy gate lookup resolves to a flight WITH the gate.
    when(
      () => service.lookupFlight(
        flightNumber: any(named: 'flightNumber'),
        date: any(named: 'date'),
        isArrival: any(named: 'isArrival'),
      ),
    ).thenAnswer((_) async => withGate);

    await pump(tester); // builds the row → fires _ensureGate
    await tester.pumpAndSettle(); // let the lookup resolve + re-render

    verify(
      () => service.lookupFlight(
        flightNumber: 'LH2001',
        date: any(named: 'date'),
        isArrival: true,
      ),
    ).called(greaterThanOrEqualTo(1));
    // Gate now shown inline in the row's terminal line.
    expect(find.textContaining('Gate G35'), findsOneWidget);
  });
}
