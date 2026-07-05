// Locks in the German-translation review (chore/de-l10n-review): a batch of
// grammar, meaning-drift, consistency and untranslated-anglicism fixes to
// app_de.arb. Each assertion below fails if the corresponding fix is reverted,
// so the corrected German strings cannot silently regress.
//
// These are pure-Dart tests loaded via AppLocalizations.delegate (no widget
// pump), matching the other test/l10n/*_test.dart specs.

import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppLocalizations> _l10n(String languageCode) async {
  final locale = Locale(languageCode);
  return AppLocalizations.delegate.load(locale);
}

void main() {
  group('DE translation quality — grammar fixes', () {
    test('Fahrtstatus has no erroneous double-s (Fahrtsstatus)', () async {
      final de = await _l10n('de');
      expect(de.rideStatusLabel, equals('Fahrtstatus'));
      expect(de.rideStatusUpdatedSuccess, equals('Fahrtstatus erfolgreich aktualisiert'));
      expect(de.rideStatusBreakdownTitle, equals('Fahrtstatus-Übersicht'));
    });

    test('separable verb ablehnen is split correctly in confirmationRequestBody', () async {
      final de = await _l10n('de');
      // The wrong form "bestätigen oder ablehnen Sie" must not come back.
      expect(de.confirmationRequestBody, isNot(contains('ablehnen Sie')));
      expect(de.confirmationRequestBody, contains('ab'));
    });

    test('rideStatusInProgressClientLabel uses correct idiom', () async {
      final de = await _l10n('de');
      expect(de.rideStatusInProgressClientLabel, equals('Fahrt läuft'));
      expect(de.rideStatusInProgressClientLabel, isNot(contains('in Gange')));
    });

    test('emergencyReasonDriverNoShow word order is correct', () async {
      final de = await _l10n('de');
      expect(de.emergencyReasonDriverNoShow, equals('Fahrer nicht erschienen'));
    });

    test('weak-declension Kunden (Akkusativ) is used', () async {
      final de = await _l10n('de');
      expect(de.bookWithoutClient, equals('Ohne Kunden (aus Chat)'));
      expect(de.linkClient, equals('Kunden ergänzen'));
    });

    test('receiptDownloadError is a proper compound', () async {
      final de = await _l10n('de');
      expect(de.receiptDownloadError('X'), startsWith('Quittungsfehler'));
    });
  });

  group('DE translation quality — meaning matches English', () {
    test('service-area (not delivery-area) wording for transfers', () async {
      final de = await _l10n('de');
      expect(de.addressOutOfServiceArea(1, 2), contains('Servicegebiet'));
      expect(de.addressOutOfServiceAreaShort(2), contains('Servicegebiet'));
      expect(de.addressOutOfServiceArea(1, 2), isNot(contains('Liefergebiet')));
    });

    test('markAllReadButton keeps the "mark" action', () async {
      final de = await _l10n('de');
      expect(de.markAllReadButton, equals('Alle als gelesen markieren'));
    });

    test('notifPrefDriverApproachingSubtitle keeps "pickup" (Abholung)', () async {
      final de = await _l10n('de');
      expect(de.notifPrefDriverApproachingSubtitle, contains('Abholung'));
    });

    test('consentAnalyticsSubtitle keeps "improve the app"', () async {
      final de = await _l10n('de');
      expect(de.consentAnalyticsSubtitle, contains('verbessern'));
    });
  });

  group('DE translation quality — consistency', () {
    test('Unternehmen is used instead of Firma', () async {
      final de = await _l10n('de');
      expect(de.clientCompanyFieldLabel, equals('Unternehmen'));
      expect(de.clientCompanyNone, equals('Kein Unternehmen'));
      expect(de.myCompanyGroupLabel, equals('Mein Unternehmen'));
    });

    test('minutes abbreviation is canonical "Min."', () async {
      final de = await _l10n('de');
      expect(de.driverDelayedMessage('Hans', '-3'), endsWith('Min.'));
      expect(de.airportFlightDelay(5), equals('+5 Min. Verspätung'));
    });

    test('clipboard confirmations use "in die Zwischenablage"', () async {
      final de = await _l10n('de');
      expect(de.dataExportCopied, contains('in die Zwischenablage'));
      expect(de.payrollCsvCopiedMessage, contains('in die Zwischenablage'));
      expect(de.csvCopiedSnackbar(3), contains('in die Zwischenablage kopiert'));
    });

    test('Disponenten-Pool is used consistently in conflict dialogs', () async {
      final de = await _l10n('de');
      expect(de.conflictDialogContent('X'), contains('Disponenten-Pool'));
      expect(de.conflictDialogContentDefault, contains('Disponenten-Pool'));
    });
  });

  group('DE translation quality — no leftover anglicisms', () {
    test('language name English is translated to Englisch', () async {
      final de = await _l10n('de');
      expect(de.english, equals('Englisch'));
      expect(de.languageEnglish, equals('Englisch'));
    });

    test('billing rail labels are translated', () async {
      final de = await _l10n('de');
      expect(de.invoicesRailLabel, equals('Rechnungen'));
      expect(de.clientsRailLabel, equals('Kunden'));
    });
  });
}
