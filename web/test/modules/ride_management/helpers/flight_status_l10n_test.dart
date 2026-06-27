// Unit tests for the localizedFlightStatus helper: every backend wire status maps to a
// localized label, and unknown/null are handled gracefully (no raw wire string leaks).

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/l10n/app_localizations_en.dart';
import 'package:dispax/l10n/app_localizations_de.dart';
import 'package:dispax/modules/ride_management/helpers/flight_status_l10n.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
