// Unit tests for the localizedFlightStatus helper: every backend wire status maps to a
// localized label, and unknown/null are handled gracefully (no raw wire string leaks).
// Plus airportScheduledLine: the two-line "Planmäßig HH:mm → …" variant must keep the
// fact/forecast landing marker (Gelandet/Landung) on its actual side — exactly on a
// delayed flight the driver needs to know whether the plane is already down.

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/l10n/app_localizations_en.dart';
import 'package:dispax/l10n/app_localizations_de.dart';
import 'package:dispax/modules/ride_management/helpers/flight_status_l10n.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  final AppLocalizations en = AppLocalizationsEn();
  final AppLocalizations de = AppLocalizationsDe();

  group('localizedFlightStatus (en)', () {
    test('maps each backend wire status to its English label', () {
      expect(en.localizedFlightStatus('scheduled'), 'Scheduled');
      expect(en.localizedFlightStatus('boarding'), 'Boarding');
      expect(en.localizedFlightStatus('departed'), 'Departed');
      expect(en.localizedFlightStatus('en_route'), 'En route');
      expect(en.localizedFlightStatus('landed'), 'Landed');
      expect(en.localizedFlightStatus('delayed'), 'Delayed');
      expect(en.localizedFlightStatus('cancelled'), 'Cancelled');
      expect(en.localizedFlightStatus('diverted'), 'Diverted');
    });

    test('unknown / unmapped → the Unknown label (never the raw string)', () {
      expect(en.localizedFlightStatus('unknown'), 'Unknown');
      expect(en.localizedFlightStatus('something-weird'), 'Unknown');
    });

    test('null → empty string', () {
      expect(en.localizedFlightStatus(null), '');
    });
  });

  group('localizedFlightStatus (de)', () {
    test('translates the status into German', () {
      expect(de.localizedFlightStatus('delayed'), 'Verspätet');
      expect(de.localizedFlightStatus('landed'), 'Gelandet');
      expect(de.localizedFlightStatus('unknown'), 'Unbekannt');
    });
  });

  group('airportScheduledLine', () {
    test('a delayed flight still airborne keeps the forecast marker', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightScheduledTime: DateTime(2026, 7, 3, 14, 0),
        flightTime: DateTime(2026, 7, 3, 14, 35),
        flightStatus: 'en_route',
      );

      expect(
        en.airportScheduledLine(ride),
        'Scheduled 14:00 → Landing at 14:35',
      );
      expect(
        de.airportScheduledLine(ride),
        'Planmäßig 14:00 → Landung um 14:35',
      );
    });

    test('a delayed flight that has landed carries the landing fact', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightScheduledTime: DateTime(2026, 7, 3, 14, 0),
        flightTime: DateTime(2026, 7, 3, 14, 35),
        flightStatus: 'landed',
      );

      expect(
        en.airportScheduledLine(ride),
        'Scheduled 14:00 → Landed at 14:35',
        reason:
            'the two-line variant must not drop the fact/forecast marker: on '
            'a delayed flight the driver needs to know the plane is down',
      );
      expect(
        de.airportScheduledLine(ride),
        'Planmäßig 14:00 → Gelandet um 14:35',
      );
    });

    test('an on-time flight (to the minute) shows no scheduled line', () {
      final onTime = DateTime(2026, 7, 3, 14, 0);
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightScheduledTime: onTime,
        flightTime: onTime,
        flightStatus: 'landed',
      );

      expect(en.airportScheduledLine(ride), isNull);
    });

    test('no scheduled time published → no scheduled line', () {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightTime: DateTime(2026, 7, 3, 14, 35),
      );

      expect(en.airportScheduledLine(ride), isNull);
    });
  });
}
