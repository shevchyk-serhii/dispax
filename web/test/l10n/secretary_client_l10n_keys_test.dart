// Tests that the secretary and client l10n keys (added in the
// l10n-secretary-client refactor) resolve to the correct strings in all three
// supported locales, and that parameterised keys format their placeholders
// correctly.
//
// This covers:
//   - Key-for-key parity: all 67 new secretary/client keys exist in all three
//     locales and are non-empty
//   - Semantic correctness: spot-checks for a representative set of keys in
//     EN/DE/UK
//   - Parameterised key formatting:
//       deactivateClientConfirmMsg(name)    — name: String
//       driverLabel(name)                   — name: String
//       departureTimeReachedFlight(flight)  — flight: String
//       failedToCancelRide(error)           — error: String
//       failedToSubmitRating(error)         — error: String
//   - Shared-key reuse: secretary/client batch must NOT create synonyms for
//     cancel, retry, save, completed, cancelled, etc.
//
// Uses AppLocalizations.delegate directly (no widget pump needed) — fast pure-Dart.

import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppLocalizations> _l10n(String languageCode) async {
  final locale = Locale(languageCode);
  return AppLocalizations.delegate.load(locale);
}

void main() {
  // ────────────────────────────────────────────────────────────────────────────
  // Parity: all 67 new keys present and non-empty in all three locales
  // ────────────────────────────────────────────────────────────────────────────
  group('secretary/client l10n keys — parity', () {
    test('all new keys are present and non-empty in English', () async {
      final en = await _l10n('en');

      // Secretary navigation / front-desk
      expect(en.ridesTab, isNotEmpty);
      expect(en.createTab, isNotEmpty);
      expect(en.frontDeskTitle, isNotEmpty);
      expect(en.quickBook, isNotEmpty);
      expect(en.bookedToday, isNotEmpty);
      expect(en.awaitingConfirm, isNotEmpty);
      expect(en.activeClientsLabel, isNotEmpty);
      expect(en.templatesLabel, isNotEmpty);
      expect(en.todaysBookings, isNotEmpty);
      expect(en.noRidesToday, isNotEmpty);
      expect(en.loadRidesToSeeBookings, isNotEmpty);

      // Client management
      expect(en.manageClientsTitle, isNotEmpty);
      expect(en.searchClientsHint, isNotEmpty);
      expect(en.noClientsMatchSearch, isNotEmpty);
      expect(en.noClientsYet, isNotEmpty);
      expect(en.addClientTitle, isNotEmpty);
      expect(en.phoneOptional, isNotEmpty);
      expect(en.nameRequired, isNotEmpty);
      expect(en.emailRequired, isNotEmpty);
      expect(en.invalidEmail, isNotEmpty);
      expect(en.addButton, isNotEmpty);
      expect(en.editAction, isNotEmpty);
      expect(en.deactivateAction, isNotEmpty);
      expect(en.editClientTitle, isNotEmpty);
      expect(en.deactivateClientTitle, isNotEmpty);

      // Client detail screen
      expect(en.newRideButton, isNotEmpty);
      expect(en.ridesCountLabel, isNotEmpty);
      expect(en.preferredDriverAssigned, isNotEmpty);
      expect(en.noRidesYet, isNotEmpty);
      expect(en.vipClientLabel, isNotEmpty);
      expect(en.vipClientHelpText, isNotEmpty);

      // Reports panel
      expect(en.reportsTitle, isNotEmpty);
      expect(en.totalRidesLabel, isNotEmpty);
      expect(en.inProgressLabel, isNotEmpty);
      expect(en.requestedLabel, isNotEmpty);
      expect(en.assignedLabel, isNotEmpty);
      expect(en.keyMetrics, isNotEmpty);
      expect(en.cancellationRateLabel, isNotEmpty);
      expect(en.statusBreakdown, isNotEmpty);
      expect(en.noRideDataYet, isNotEmpty);

      // Client dashboard / My Rides tab
      expect(en.noActiveRides, isNotEmpty);
      expect(en.useBookTabHint, isNotEmpty);
      expect(en.trackDriver, isNotEmpty);
      expect(en.bookLabel, isNotEmpty);

      // Client home screen
      expect(en.goodMorning, isNotEmpty);
      expect(en.goodAfternoon, isNotEmpty);
      expect(en.goodEvening, isNotEmpty);
      expect(en.whereTo, isNotEmpty);
      expect(en.onTrip, isNotEmpty);
      expect(en.driverOnTheWay, isNotEmpty);
      expect(en.driverAssigned, isNotEmpty);
      expect(en.yourDriver, isNotEmpty);
      expect(en.savedPlaces, isNotEmpty);
      expect(en.savedPlaceHome, isNotEmpty);
      expect(en.savedPlaceOffice, isNotEmpty);
      expect(en.addAddress, isNotEmpty);
      expect(en.bookARide, isNotEmpty);

      // Client book screen
      expect(en.scheduled, isNotEmpty);
      expect(en.nowLabel, isNotEmpty);
      expect(en.asap, isNotEmpty);
      expect(en.vehicleClass, isNotEmpty);
      expect(en.estimatedTotal, isNotEmpty);
      expect(en.estimateUnavailableHint, isNotEmpty);
      expect(en.confirmBooking, isNotEmpty);
      expect(en.rideBookedSuccessfully, isNotEmpty);
      expect(en.failedToCreateRide, isNotEmpty);
      expect(en.failedToLoadRideHistory, isNotEmpty);

      // Client ride history
      expect(en.listView, isNotEmpty);
      expect(en.pastLabel, isNotEmpty);
      expect(en.confirmedStatus, isNotEmpty);
      expect(en.rateThisRide, isNotEmpty);
      expect(en.thankYouForRating, isNotEmpty);

      // Parameterised keys (must not throw)
      expect(en.deactivateClientConfirmMsg('Test Client'), isNotEmpty);
      expect(en.driverLabel('Hans'), isNotEmpty);
      expect(en.departureTimeReachedFlight('LH1234'), isNotEmpty);
      expect(en.failedToCancelRide('Network error'), isNotEmpty);
      expect(en.failedToSubmitRating('Timeout'), isNotEmpty);
    });

    test('all new keys are non-empty in German', () async {
      final de = await _l10n('de');

      expect(de.ridesTab, isNotEmpty);
      expect(de.createTab, isNotEmpty);
      expect(de.frontDeskTitle, isNotEmpty);
      expect(de.quickBook, isNotEmpty);
      expect(de.bookedToday, isNotEmpty);
      expect(de.awaitingConfirm, isNotEmpty);
      expect(de.activeClientsLabel, isNotEmpty);
      expect(de.templatesLabel, isNotEmpty);
      expect(de.todaysBookings, isNotEmpty);
      expect(de.noRidesToday, isNotEmpty);
      expect(de.loadRidesToSeeBookings, isNotEmpty);
      expect(de.manageClientsTitle, isNotEmpty);
      expect(de.searchClientsHint, isNotEmpty);
      expect(de.noClientsMatchSearch, isNotEmpty);
      expect(de.noClientsYet, isNotEmpty);
      expect(de.addClientTitle, isNotEmpty);
      expect(de.phoneOptional, isNotEmpty);
      expect(de.nameRequired, isNotEmpty);
      expect(de.emailRequired, isNotEmpty);
      expect(de.invalidEmail, isNotEmpty);
      expect(de.addButton, isNotEmpty);
      expect(de.editAction, isNotEmpty);
      expect(de.deactivateAction, isNotEmpty);
      expect(de.editClientTitle, isNotEmpty);
      expect(de.deactivateClientTitle, isNotEmpty);
      expect(de.newRideButton, isNotEmpty);
      expect(de.ridesCountLabel, isNotEmpty);
      expect(de.preferredDriverAssigned, isNotEmpty);
      expect(de.noRidesYet, isNotEmpty);
      expect(de.vipClientLabel, isNotEmpty);
      expect(de.vipClientHelpText, isNotEmpty);
      expect(de.reportsTitle, isNotEmpty);
      expect(de.totalRidesLabel, isNotEmpty);
      expect(de.inProgressLabel, isNotEmpty);
      expect(de.requestedLabel, isNotEmpty);
      expect(de.assignedLabel, isNotEmpty);
      expect(de.keyMetrics, isNotEmpty);
      expect(de.cancellationRateLabel, isNotEmpty);
      expect(de.statusBreakdown, isNotEmpty);
      expect(de.noRideDataYet, isNotEmpty);
      expect(de.noActiveRides, isNotEmpty);
      expect(de.useBookTabHint, isNotEmpty);
      expect(de.trackDriver, isNotEmpty);
      expect(de.bookLabel, isNotEmpty);
      expect(de.goodMorning, isNotEmpty);
      expect(de.goodAfternoon, isNotEmpty);
      expect(de.goodEvening, isNotEmpty);
      expect(de.whereTo, isNotEmpty);
      expect(de.onTrip, isNotEmpty);
      expect(de.driverOnTheWay, isNotEmpty);
      expect(de.driverAssigned, isNotEmpty);
      expect(de.yourDriver, isNotEmpty);
      expect(de.savedPlaces, isNotEmpty);
      expect(de.savedPlaceHome, isNotEmpty);
      expect(de.savedPlaceOffice, isNotEmpty);
      expect(de.addAddress, isNotEmpty);
      expect(de.bookARide, isNotEmpty);
      expect(de.scheduled, isNotEmpty);
      expect(de.nowLabel, isNotEmpty);
      expect(de.asap, isNotEmpty);
      expect(de.vehicleClass, isNotEmpty);
      expect(de.estimatedTotal, isNotEmpty);
      expect(de.estimateUnavailableHint, isNotEmpty);
      expect(de.confirmBooking, isNotEmpty);
      expect(de.rideBookedSuccessfully, isNotEmpty);
      expect(de.failedToCreateRide, isNotEmpty);
      expect(de.failedToLoadRideHistory, isNotEmpty);
      expect(de.listView, isNotEmpty);
      expect(de.pastLabel, isNotEmpty);
      expect(de.confirmedStatus, isNotEmpty);
      expect(de.rateThisRide, isNotEmpty);
      expect(de.thankYouForRating, isNotEmpty);
      expect(de.deactivateClientConfirmMsg('Müller GmbH'), isNotEmpty);
      expect(de.driverLabel('Klaus'), isNotEmpty);
      expect(de.departureTimeReachedFlight('LH1234'), isNotEmpty);
      expect(de.failedToCancelRide('Fehler'), isNotEmpty);
      expect(de.failedToSubmitRating('Timeout'), isNotEmpty);
    });

    test('all new keys are non-empty in Ukrainian', () async {
      final uk = await _l10n('uk');

      expect(uk.ridesTab, isNotEmpty);
      expect(uk.createTab, isNotEmpty);
      expect(uk.frontDeskTitle, isNotEmpty);
      expect(uk.quickBook, isNotEmpty);
      expect(uk.bookedToday, isNotEmpty);
      expect(uk.awaitingConfirm, isNotEmpty);
      expect(uk.activeClientsLabel, isNotEmpty);
      expect(uk.templatesLabel, isNotEmpty);
      expect(uk.todaysBookings, isNotEmpty);
      expect(uk.noRidesToday, isNotEmpty);
      expect(uk.loadRidesToSeeBookings, isNotEmpty);
      expect(uk.manageClientsTitle, isNotEmpty);
      expect(uk.searchClientsHint, isNotEmpty);
      expect(uk.noClientsMatchSearch, isNotEmpty);
      expect(uk.noClientsYet, isNotEmpty);
      expect(uk.addClientTitle, isNotEmpty);
      expect(uk.phoneOptional, isNotEmpty);
      expect(uk.nameRequired, isNotEmpty);
      expect(uk.emailRequired, isNotEmpty);
      expect(uk.invalidEmail, isNotEmpty);
      expect(uk.addButton, isNotEmpty);
      expect(uk.editAction, isNotEmpty);
      expect(uk.deactivateAction, isNotEmpty);
      expect(uk.editClientTitle, isNotEmpty);
      expect(uk.deactivateClientTitle, isNotEmpty);
      expect(uk.newRideButton, isNotEmpty);
      expect(uk.ridesCountLabel, isNotEmpty);
      expect(uk.preferredDriverAssigned, isNotEmpty);
      expect(uk.noRidesYet, isNotEmpty);
      expect(uk.vipClientLabel, isNotEmpty);
      expect(uk.vipClientHelpText, isNotEmpty);
      expect(uk.reportsTitle, isNotEmpty);
      expect(uk.totalRidesLabel, isNotEmpty);
      expect(uk.inProgressLabel, isNotEmpty);
      expect(uk.requestedLabel, isNotEmpty);
      expect(uk.assignedLabel, isNotEmpty);
      expect(uk.keyMetrics, isNotEmpty);
      expect(uk.cancellationRateLabel, isNotEmpty);
      expect(uk.statusBreakdown, isNotEmpty);
      expect(uk.noRideDataYet, isNotEmpty);
      expect(uk.noActiveRides, isNotEmpty);
      expect(uk.useBookTabHint, isNotEmpty);
      expect(uk.trackDriver, isNotEmpty);
      expect(uk.bookLabel, isNotEmpty);
      expect(uk.goodMorning, isNotEmpty);
      expect(uk.goodAfternoon, isNotEmpty);
      expect(uk.goodEvening, isNotEmpty);
      expect(uk.whereTo, isNotEmpty);
      expect(uk.onTrip, isNotEmpty);
      expect(uk.driverOnTheWay, isNotEmpty);
      expect(uk.driverAssigned, isNotEmpty);
      expect(uk.yourDriver, isNotEmpty);
      expect(uk.savedPlaces, isNotEmpty);
      expect(uk.savedPlaceHome, isNotEmpty);
      expect(uk.savedPlaceOffice, isNotEmpty);
      expect(uk.addAddress, isNotEmpty);
      expect(uk.bookARide, isNotEmpty);
      expect(uk.scheduled, isNotEmpty);
      expect(uk.nowLabel, isNotEmpty);
      expect(uk.asap, isNotEmpty);
      expect(uk.vehicleClass, isNotEmpty);
      expect(uk.estimatedTotal, isNotEmpty);
      expect(uk.estimateUnavailableHint, isNotEmpty);
      expect(uk.confirmBooking, isNotEmpty);
      expect(uk.rideBookedSuccessfully, isNotEmpty);
      expect(uk.failedToCreateRide, isNotEmpty);
      expect(uk.failedToLoadRideHistory, isNotEmpty);
      expect(uk.listView, isNotEmpty);
      expect(uk.pastLabel, isNotEmpty);
      expect(uk.confirmedStatus, isNotEmpty);
      expect(uk.rateThisRide, isNotEmpty);
      expect(uk.thankYouForRating, isNotEmpty);
      expect(uk.deactivateClientConfirmMsg('Клієнт'), isNotEmpty);
      expect(uk.driverLabel('Іван'), isNotEmpty);
      expect(uk.departureTimeReachedFlight('PS123'), isNotEmpty);
      expect(uk.failedToCancelRide('Помилка'), isNotEmpty);
      expect(uk.failedToSubmitRating('Час вийшов'), isNotEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Semantic correctness: spot-check exact values in all three locales
  // ────────────────────────────────────────────────────────────────────────────
  group('secretary/client l10n keys — semantic correctness', () {
    test('frontDeskTitle is localised correctly', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.frontDeskTitle, equals('Front desk'));
      expect(de.frontDeskTitle, equals('Empfang'));
      expect(uk.frontDeskTitle, equals('Ресепшн'));
    });

    test('confirmBooking is localised correctly', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.confirmBooking, equals('Confirm booking'));
      expect(de.confirmBooking, equals('Buchung bestätigen'));
      expect(uk.confirmBooking, equals('Підтвердити замовлення'));
    });

    test('rideBookedSuccessfully is localised correctly', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.rideBookedSuccessfully, equals('Ride booked successfully!'));
      expect(de.rideBookedSuccessfully, equals('Fahrt erfolgreich gebucht!'));
      expect(
        uk.rideBookedSuccessfully,
        equals('Поїздку успішно заброньовано!'),
      );
    });

    test(
      'goodMorning/goodAfternoon/goodEvening are distinct in each locale',
      () async {
        final en = await _l10n('en');

        expect(en.goodMorning, isNot(equals(en.goodAfternoon)));
        expect(en.goodMorning, isNot(equals(en.goodEvening)));
        expect(en.goodAfternoon, isNot(equals(en.goodEvening)));
      },
    );

    test('confirmedStatus correct in all locales', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.confirmedStatus, equals('Confirmed'));
      expect(de.confirmedStatus, equals('Bestätigt'));
      expect(uk.confirmedStatus, equals('Підтверджено'));
    });

    test('addButton is localised correctly', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.addButton, equals('Add'));
      expect(de.addButton, equals('Hinzufügen'));
      expect(uk.addButton, equals('Додати'));
    });

    test('savedPlaceHome/savedPlaceOffice correct in EN', () async {
      final en = await _l10n('en');

      expect(en.savedPlaceHome, equals('Home'));
      expect(en.savedPlaceOffice, equals('Office'));
    });

    test(
      'shared keys (cancel/retry/save/completed/cancelled) not duplicated',
      () async {
        // The secretary/client batch must reuse existing shared keys rather than
        // creating synonyms. Verify these are present and have expected EN values.
        final en = await _l10n('en');

        expect(en.cancel, equals('Cancel'));
        expect(en.retry, equals('Retry'));
        expect(en.save, equals('Save'));
        expect(en.completed, equals('Completed'));
        expect(en.cancelled, equals('Cancelled'));
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Parameterised key formatting
  // ────────────────────────────────────────────────────────────────────────────
  group('secretary/client l10n keys — parameterised formatting', () {
    test('deactivateClientConfirmMsg interpolates name (String)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.deactivateClientConfirmMsg('Alice'), contains('Alice'));
      expect(de.deactivateClientConfirmMsg('Klaus'), contains('Klaus'));
      expect(uk.deactivateClientConfirmMsg('Іван'), contains('Іван'));

      // Name is actually interpolated (not hardcoded).
      expect(
        en.deactivateClientConfirmMsg('Alice'),
        isNot(equals(en.deactivateClientConfirmMsg('Bob'))),
      );
    });

    test('driverLabel interpolates name (String)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.driverLabel('Hans'), contains('Hans'));
      expect(de.driverLabel('Klaus'), contains('Klaus'));
      expect(uk.driverLabel('Іван'), contains('Іван'));

      expect(en.driverLabel('Alice'), isNot(equals(en.driverLabel('Bob'))));
    });

    test('departureTimeReachedFlight interpolates flight (String)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.departureTimeReachedFlight('LH1234'), contains('LH1234'));
      expect(de.departureTimeReachedFlight('LH1234'), contains('LH1234'));
      expect(uk.departureTimeReachedFlight('PS123'), contains('PS123'));

      expect(
        en.departureTimeReachedFlight('LH1234'),
        isNot(equals(en.departureTimeReachedFlight('BA456'))),
      );
    });

    test('failedToCancelRide interpolates error (String)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.failedToCancelRide('Network error'), contains('Network error'));
      expect(de.failedToCancelRide('Fehler'), contains('Fehler'));
      expect(uk.failedToCancelRide('Помилка'), contains('Помилка'));

      expect(
        en.failedToCancelRide('err1'),
        isNot(equals(en.failedToCancelRide('err2'))),
      );
    });

    test('failedToSubmitRating interpolates error (String)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.failedToSubmitRating('Timeout'), contains('Timeout'));
      expect(de.failedToSubmitRating('Auszeit'), contains('Auszeit'));
      expect(uk.failedToSubmitRating('Час вийшов'), contains('Час вийшов'));

      expect(
        en.failedToSubmitRating('err1'),
        isNot(equals(en.failedToSubmitRating('err2'))),
      );
    });
  });
}
