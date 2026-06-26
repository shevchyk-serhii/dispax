// Covers the wire contract + UI of the airport terminal-entry timing feature:
//   - AirportTiming.fromJson parses the backend JSON, including the new optional `actualArrivalTime` field, and the
//     derived helpers (shouldDepartNow / formattedOptimalEntryTime / formattedSavings).
//   - AirportEntryTimer renders the localized "Airport Entry Time" header for an active airport transfer and renders
//     nothing for a non-airport ride (the build()-level guard).
//
// The card's network load is driven by singletons (LocationService / AirportTimingService) that need platform
// geolocation + an authenticated ApiClient, so the widget test asserts the localized chrome (header), not a live
// timing fetch — the timing math itself is covered by the backend AirportTimingServiceSpec.

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/flight_management/models/airport_timing.dart';
import 'package:dispax/modules/flight_management/widgets/airport_entry_timer.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Ride _ride({required bool isAirportTransfer, bool isArrival = true}) => Ride(
  id: 'ride-1',
  clientId: 'c1',
  creatorId: 'u1',
  companyId: 'company-1',
  pickupDateTime: DateTime.now().add(const Duration(hours: 2)),
  from: const Location(address: 'Home'),
  to: const Location(address: 'MUC Terminal 2'),
  clientName: 'Bruno Aldi',
  status: RideStatus.assigned,
  isAirportTransfer: isAirportTransfer,
  isArrival: isArrival,
  flightTime: DateTime.now().add(const Duration(hours: 3)),
);

Widget _host(Ride ride) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  locale: const Locale('en'),
  home: Scaffold(body: AirportEntryTimer(ride: ride)),
);

void main() {
  group('AirportTiming.fromJson', () {
    final base = <String, dynamic>{
      'optimalEntryTime': '2026-07-01T08:00:00.000Z',
      'latestEntryTime': '2026-07-01T08:10:00.000Z',
      'travelTimeMinutes': 20,
      'bufferTimeMinutes': 10,
      'optimalParkingCost': 0.0,
      'earlyEntryParkingCost': 28.0,
      'savings': 28.0,
      'flightStatus': 'On time',
      'timeToDepartMinutes': 35,
    };

    test('parses the backend contract and derives helpers', () {
      final timing = AirportTiming.fromJson(base);
      expect(timing.travelTime.inMinutes, 20);
      expect(timing.bufferTime.inMinutes, 10);
      expect(timing.savings, 28.0);
      expect(timing.formattedSavings, '€28.00');
      expect(timing.formattedOptimalEntryTime, '08:00');
      expect(timing.shouldDepartNow, isFalse);
      expect(timing.actualArrivalTime, isNull);
    });

    test('parses the optional actualArrivalTime when present', () {
      final json = Map<String, dynamic>.from(base)
        ..['actualArrivalTime'] = '2026-07-01T08:00:00.000Z';
      final timing = AirportTiming.fromJson(json);
      expect(timing.actualArrivalTime, isNotNull);
      expect(
        timing.actualArrivalTime!.toUtc(),
        DateTime.utc(2026, 7, 1, 8, 0, 0),
      );
    });

    test('shouldDepartNow when timeToDepart <= 0', () {
      final json = Map<String, dynamic>.from(base)..['timeToDepartMinutes'] = 0;
      expect(AirportTiming.fromJson(json).shouldDepartNow, isTrue);
    });
  });

  group('AirportEntryTimer', () {
    testWidgets('renders the localized header for an airport transfer', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_ride(isAirportTransfer: true)));
      await tester.pump();
      expect(find.text('Airport Entry Time'), findsOneWidget);
    });

    testWidgets('renders nothing for a non-airport ride', (tester) async {
      await tester.pumpWidget(_host(_ride(isAirportTransfer: false)));
      await tester.pump();
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('Airport Entry Time'), findsNothing);
    });
  });
}
