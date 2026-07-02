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

    testWidgets('delayed arrival past its landing time lights up "Im Flug" '
        '(red), not "Planmäßig"', (tester) async {
      // Regression for the LH2091 card, built from the REAL delayed-arrival DTO
      // shape verified against live MUC data: NO departure time, NO estimate —
      // only a (past) scheduled landing time. It used to default to "Planmäßig";
      // now that the landing time has arrived it must sit on "Im Flug", red.
      final now = DateTime.now();
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(
            isArrival: true,
            flightStatus: 'delayed',
            // flightTime = the landing time, already in the past. No departure.
            flightTime: now.subtract(const Duration(minutes: 10)),
          ),
        ),
      );
      const green = Color(0xFF4CAF50);
      const red = Color(0xFFD32F2F);
      // scheduled completed (green), enRoute is the current (red, delayed) step.
      expect(labelColor(tester, 'Planmäßig'), green);
      expect(labelColor(tester, 'Im Flug'), red);
      expect(labelColor(tester, 'Gelandet'), const Color(0xFF9E9E9E));
    });

    testWidgets('delayed arrival with a full window past landing lights up '
        '"Gelandet" — the phase follows the plane', (tester) async {
      // The user-reported case: the plane sits at the right (estimated landing
      // passed) but "Im Flug"/"Gelandet" stayed grey. With a full window the
      // phase now tracks the same progress fraction as the plane: progress >= 1
      // → "Gelandet" is the active (red, delayed) step, in sync with the plane.
      final now = DateTime.now();
      await _pump(
        tester,
        FlightProgressBar.forRide(
          _airportRide(
            isArrival: true,
            flightStatus: 'delayed',
            flightDepartureTime: now.subtract(const Duration(hours: 2)),
            flightTime: now.subtract(
              const Duration(minutes: 10),
            ), // landed-by-time
          ),
        ),
      );
      const green = Color(0xFF4CAF50);
      const red = Color(0xFFD32F2F);
      expect(labelColor(tester, 'Planmäßig'), green);
      expect(labelColor(tester, 'Im Flug'), green); // completed
      expect(labelColor(tester, 'Gelandet'), red); // current, delayed
    });
  });

  group('FlightProgressBar airplane (spans the whole bar by flight time)', () {
    // Pump the bar at a fixed width and return the plane's x measured from the
    // bar's own left edge (0..300), so assertions are independent of where the
    // centered bar sits on the test surface.
    Future<double> planeCenterX(WidgetTester tester, Ride ride) async {
      await _pump(
        tester,
        Center(
          child: SizedBox(width: 300, child: FlightProgressBar.forRide(ride)),
        ),
      );
      // Settle the one-shot AnimatedPositioned (300ms) — needed when the same
      // tester is re-pumped with a new window within one test (the plane then
      // animates from its previous x to the new one).
      await tester.pump(const Duration(milliseconds: 350));
      final barLeft = tester.getTopLeft(find.byType(FlightProgressBar)).dx;
      return tester.getCenter(find.byIcon(Icons.flight)).dx - barLeft;
    }

    testWidgets('en-route arrival with a window shows the airplane mid-bar', (
      tester,
    ) async {
      final now = DateTime.now();
      final x = await planeCenterX(
        tester,
        _airportRide(
          isArrival: true,
          flightStatus: 'en_route',
          // Halfway through the flight → plane around the middle of the 300px bar.
          flightDepartureTime: now.subtract(const Duration(hours: 1)),
          flightTime: now.add(const Duration(hours: 1)),
        ),
      );
      expect(x, greaterThan(100));
      expect(x, lessThan(200));
    });

    testWidgets('not-yet-departed (scheduled) arrival parks the plane at the '
        'left ("Planmäßig")', (tester) async {
      final now = DateTime.now();
      final x = await planeCenterX(
        tester,
        _airportRide(
          isArrival: true,
          flightStatus: 'scheduled',
          // Departure is in the future → progress clamps to 0 → parked far left.
          flightDepartureTime: now.add(const Duration(hours: 1)),
          flightTime: now.add(const Duration(hours: 3)),
        ),
      );
      expect(x, lessThan(60));
    });

    testWidgets('landed arrival parks the plane at the right ("Gelandet")', (
      tester,
    ) async {
      final now = DateTime.now();
      final x = await planeCenterX(
        tester,
        _airportRide(
          isArrival: true,
          flightStatus: 'landed',
          // Arrival is in the past → progress clamps to 1 → parked far right.
          flightDepartureTime: now.subtract(const Duration(hours: 2)),
          flightTime: now.subtract(const Duration(minutes: 10)),
        ),
      );
      expect(x, greaterThan(240));
    });

    testWidgets('the plane moves forward as the flight progresses (mutation '
        'guard: not pinned to one segment)', (tester) async {
      final now = DateTime.now();
      // Early in the flight (10% in).
      final early = await planeCenterX(
        tester,
        _airportRide(
          isArrival: true,
          flightStatus: 'en_route',
          flightDepartureTime: now.subtract(const Duration(minutes: 12)),
          flightTime: now.add(const Duration(minutes: 108)),
        ),
      );
      // Late in the flight (90% in).
      final late = await planeCenterX(
        tester,
        _airportRide(
          isArrival: true,
          flightStatus: 'en_route',
          flightDepartureTime: now.subtract(const Duration(minutes: 108)),
          flightTime: now.add(const Duration(minutes: 12)),
        ),
      );
      expect(late, greaterThan(early + 100));
    });

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

  group('FlightProgressBar layout', () {
    // Regression: the steps Row used to size each step to its natural label
    // width, so the 4-step German departure chain overflowed a ~300px ride card
    // by 14px (caught only by driver_ride_card_test at width 360). The all-flex
    // row + wrapping labels must fit any narrow card.
    testWidgets('departure chain does not overflow a 300px-wide card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: FlightProgressBar.forRide(
                  _airportRide(isArrival: false, flightStatus: 'departed'),
                ),
              ),
            ),
          ),
        ),
      );
      // A RenderFlex overflow surfaces as an exception during layout.
      expect(tester.takeException(), isNull);
    });
  });
}
