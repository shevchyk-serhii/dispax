// Verifies the flight-time pickers shown in the airport section of the create-ride
// form. The flight ARRIVAL picker must appear for arrival airport rides (it captures
// the flight arrival time the backend turns into the recommended terminal-entry time)
// and must NOT appear for departures (which have their own departure picker) or for
// non-airport rides.
//
// Mutation: drop the `if (isAirportTransfer && isArrival)` arrival-picker block ->
// the "shows the arrival flight-time picker" expectation goes red.

import 'package:dispax/blocs/blocs.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/widgets/sections/create_ride_airport_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool isAirportTransfer,
    required bool isArrival,
    required bool isDepartureAutoCompute,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider(
            create: (_) => CreateRideFormBloc(),
            child: SingleChildScrollView(
              child: CreateRideAirportSection(
                isAirportTransfer: isAirportTransfer,
                isArrival: isArrival,
                flightNumber: 'LH1671',
                selectedGate: null,
                selectedTerminal: null,
                isDepartureAutoCompute: isDepartureAutoCompute,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the arrival flight-time picker for an arrival', (
    tester,
  ) async {
    await pump(
      tester,
      isAirportTransfer: true,
      isArrival: true,
      isDepartureAutoCompute: false,
    );

    expect(find.text('Arrival Schedule'), findsOneWidget);
    expect(find.text('Flight arrival time (optional)'), findsOneWidget);
    // The departure card must not be shown for an arrival.
    expect(find.text('Departure Schedule'), findsNothing);
  });

  testWidgets('shows the departure picker (not arrival) for a departure', (
    tester,
  ) async {
    await pump(
      tester,
      isAirportTransfer: true,
      isArrival: false,
      isDepartureAutoCompute: true,
    );

    expect(find.text('Departure Schedule'), findsOneWidget);
    expect(find.text('Arrival Schedule'), findsNothing);
  });

  testWidgets('shows no flight-time picker for a non-airport ride', (
    tester,
  ) async {
    await pump(
      tester,
      isAirportTransfer: false,
      isArrival: false,
      isDepartureAutoCompute: false,
    );

    expect(find.text('Arrival Schedule'), findsNothing);
    expect(find.text('Departure Schedule'), findsNothing);
  });
}
