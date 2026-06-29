// Widget tests for FlightProgressBar — the per-ride flight phase stepper.
// Verifies visibility gating, direction-dependent step counts, the cancelled
// off-ramp label, and the delay badge. Runs under the German locale to lock in
// localized phase labels (and to catch a missing l10n delegate).

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/flight_management/widgets/flight_progress_bar.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _loc = Location(address: 'Flughafen München, 85356 München');

Ride _airportRide({
  required bool isArrival,
  String? flightStatus,
  String flightNumber = 'LH123',
  bool isAirportTransfer = true,
  DateTime? flightTime,
  DateTime? flightScheduledTime,
  DateTime? flightDepartureTime,
}) => Ride(
  id: 'ride-1',
  clientId: 'client-1',
  creatorId: 'creator-1',
  companyId: 'company-1',
  pickupDateTime: DateTime(2026, 6, 24, 10),
  from: _loc,
  to: _loc,
  clientName: 'BMW AG',
  status: RideStatus.assigned,
  flightNumber: isAirportTransfer ? flightNumber : null,
  flightStatus: flightStatus,
  isAirportTransfer: isAirportTransfer,
  isArrival: isArrival,
  flightTime: flightTime,
  flightScheduledTime: flightScheduledTime,
  flightDepartureTime: flightDepartureTime,
);

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('de'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('FlightProgressBar visibility', () {
    testWidgets('renders nothing for a non-airport ride', (tester) async {
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(isArrival: true, isAirportTransfer: false),
        ),
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders nothing for an unknown status', (tester) async {
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(isArrival: true, flightStatus: 'unknown'),
        ),
      );
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('FlightProgressBar steps', () {
    testWidgets('arrival shows three phase labels', (tester) async {
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(isArrival: true, flightStatus: 'en_route'),
        ),
      );
      // Arrival chain: Planmäßig, Im Flug, Gelandet.
      expect(find.text('Planmäßig'), findsOneWidget);
      expect(find.text('Im Flug'), findsOneWidget);
      expect(find.text('Gelandet'), findsOneWidget);
      expect(
        find.text('Gestartet'),
        findsNothing,
      ); // boarding/departed not in arrival chain
    });

    testWidgets('departure shows four phase labels including Gestartet', (
      tester,
    ) async {
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(isArrival: false, flightStatus: 'departed'),
        ),
      );
      // Departure chain: Planmäßig, Boarding, Gestartet, Im Flug.
      expect(find.text('Planmäßig'), findsOneWidget);
      expect(find.text('Gestartet'), findsOneWidget);
      expect(find.text('Im Flug'), findsOneWidget);
      expect(
        find.text('Gelandet'),
        findsNothing,
      ); // no landed step on departures
    });
  });

  group('FlightProgressBar arrival phase highlighting', () {
    // Color of the rendered step label, used to tell completed (green) from
    // current (amber) from pending (grey). Mirrors FlightProgressBar's palette.
    Color? labelColor(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style?.color;

    testWidgets('arrival "departed"/"Gestartet" lights up "Im Flug", not '
        '"Planmäßig"', (tester) async {
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(isArrival: true, flightStatus: 'departed'),
        ),
      );
      // departed projects onto enRoute (ordinal 1) on the arrival chain:
      // scheduled (0) is completed (green), enRoute (1) is current (amber).
      const green = Color(0xFF4CAF50);
      const amber = Color(0xFFFF9800);
      expect(labelColor(tester, 'Planmäßig'), green);
      expect(labelColor(tester, 'Im Flug'), amber);
      // Landed is still pending (grey), not the current step.
      expect(labelColor(tester, 'Gelandet'), const Color(0xFF9E9E9E));
    });
  });

  group('FlightProgressBar en-route airplane', () {
    testWidgets(
      'arrival en route with a known take-off window shows the airplane',
      (tester) async {
        final now = DateTime.now();
        await _pump(
          tester,
          FlightProgressBar.forRide(
            _airportRide(
              isArrival: true,
              flightStatus: 'en_route',
              flightDepartureTime: now.subtract(const Duration(hours: 1)),
              flightTime: now.add(const Duration(hours: 1)),
            ),
          ),
        );
        await tester.pump(); // settle the one-shot AnimatedPositioned
        expect(find.byIcon(Icons.flight), findsOneWidget);
      },
    );

    testWidgets('no airplane when the take-off time is unknown', (
      tester,
    ) async {
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(
            isArrival: true,
            flightStatus: 'en_route',
            flightTime: DateTime.now().add(const Duration(hours: 1)),
            // no flightDepartureTime
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.flight), findsNothing);
    });

    testWidgets('no airplane for a not-yet-departed (scheduled) arrival even '
        'with a window', (tester) async {
      // The monitor fills the take-off time before departure, so a scheduled
      // arrival has a full window — but the plane must not appear until "Im Flug".
      final now = DateTime.now();
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(
            isArrival: true,
            flightStatus: 'scheduled',
            flightDepartureTime: now.add(const Duration(hours: 1)),
            flightTime: now.add(const Duration(hours: 3)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.flight), findsNothing);
    });

    testWidgets('no airplane once the flight has landed', (tester) async {
      final now = DateTime.now();
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(
            isArrival: true,
            flightStatus: 'landed',
            flightDepartureTime: now.subtract(const Duration(hours: 2)),
            flightTime: now.subtract(const Duration(minutes: 10)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.flight), findsNothing);
    });
  });

  group('FlightProgressBar off-ramp and delay', () {
    testWidgets('cancelled collapses to a single label, no step dots', (
      tester,
    ) async {
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(isArrival: true, flightStatus: 'cancelled'),
        ),
      );
      expect(find.text('Gestrichen'), findsOneWidget);
      // No phase-step labels rendered.
      expect(find.text('Planmäßig'), findsNothing);
      expect(find.text('Gelandet'), findsNothing);
    });

    testWidgets('a delayed flight shows the "+N min" badge', (tester) async {
      // flightTime 20 min after scheduled → delayMinutes = 20.
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(
            isArrival: true,
            flightStatus: 'en_route',
            flightScheduledTime: DateTime(2026, 6, 24, 12, 0),
            flightTime: DateTime(2026, 6, 24, 12, 20),
          ),
        ),
      );
      // The German delay key renders the number; assert the minutes appear.
      expect(find.textContaining('20'), findsOneWidget);
    });
  });
}
