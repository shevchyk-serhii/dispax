// Consumer-side test for the driver live-flight WS fix: proves that a
// FlightStatusUpdated event flowing into the shared RideBloc (via
// RideFlightStatusReceived) actually re-renders a driver ride card bound to
// that bloc — not just that the bloc mutates state (ride_bloc_test covers the
// producer). This closes the gap the fix targets: the driver's Today/Upcoming
// cards reflect gate/terminal/status changes live, without a manual refresh.
//
// A direct `pumpWidget(TodayRideCard(ride:))` would NOT cover this — it renders
// a fixed Ride. Here the card is driven off a real RideBloc through a
// BlocBuilder, so the test exercises the subscription path end-to-end.
//
// Mutation check: make onFlightStatusReceived a no-op in ride_bloc.dart -> the
// "updates to H18" expectation goes red (the card keeps showing G12).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/blocs.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/driver_management/widgets/today_ride_card.dart';
import 'package:dispax/modules/ride_management/services/ride_service.dart';

import '../helpers/test_fixtures.dart';

class _MockRideService extends Mock implements RideService {}

void main() {
  testWidgets(
    'a FlightStatusUpdated event live-updates the gate on a driver ride card',
    (tester) async {
      final rideService = _MockRideService();
      final bloc = RideBloc(rideService: rideService)
        ..emit(
          RideState.loaded([
            TestFixtures.ride(
              id: 'ride-1',
              isAirportTransfer: true,
              flightNumber: 'LH1234',
              gate: 'G12',
              terminal: 'T1',
              flightStatus: 'Scheduled',
            ),
          ]),
        );
      addTearDown(bloc.close);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<RideBloc>.value(
              value: bloc,
              child: BlocBuilder<RideBloc, RideState>(
                builder: (context, state) => SingleChildScrollView(
                  child: TodayRideCard(
                    ride: state.rides.firstWhere((r) => r.id == 'ride-1'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Baseline: the card shows the seeded gate.
      expect(find.textContaining('Gate G12'), findsOneWidget);

      // A live MUC flight-board update arrives over WS → the app-level listener
      // dispatches this event onto the shared RideBloc.
      bloc.add(
        const RideFlightStatusReceived(
          rideId: 'ride-1',
          gate: 'H18',
          terminal: 'T2',
          flightStatus: 'Landed',
        ),
      );
      await tester.pumpAndSettle();

      // The card re-rendered with the new gate — no manual refresh.
      expect(find.textContaining('Gate H18'), findsOneWidget);
      expect(find.textContaining('Gate G12'), findsNothing);
    },
  );
}
