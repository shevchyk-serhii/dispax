// Tests that all ~96 new ride-module l10n keys (added in the l10n-ride-modules
// refactor) resolve to non-empty strings in all three supported locales, and
// that parameterised keys format their placeholders correctly.
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
  // Parity: all new keys present and non-empty in English
  // ────────────────────────────────────────────────────────────────────────────
  group('ride-modules l10n keys — EN parity', () {
    test('all new keys are present and non-empty in English', () async {
      final en = await _l10n('en');

      // ride_card
      expect(en.rideCardTimeLabel('10:00'), isNotEmpty);

      // delete_confirmation_dialog
      expect(en.deleteConfirmationTitle, isNotEmpty);
      expect(en.deleteRideConfirmMessage('A', 'B'), isNotEmpty);

      // cancel_ride_dialog
      expect(en.cancelRideDialogTitle, isNotEmpty);
      expect(en.selectCancellationReason, isNotEmpty);
      expect(en.cancellationReasonLabel, isNotEmpty);
      expect(en.cancellationReasonClientRequest, isNotEmpty);
      expect(en.cancellationReasonWeather, isNotEmpty);
      expect(en.cancellationReasonOther, isNotEmpty);
      expect(en.cancellationReasonClientNoShow, isNotEmpty);
      expect(en.cancellationReasonDriverUnavailable, isNotEmpty);
      expect(en.cancellationReasonVehicleIssue, isNotEmpty);
      expect(en.cancellationFeeLabel, isNotEmpty);

      // rate_ride_dialog
      expect(en.rateRideExperienceQuestion, isNotEmpty);
      expect(en.rateRideCommentLabel, isNotEmpty);
      expect(en.rateRideCommentHint, isNotEmpty);

      // airport_transfer_card
      expect(en.airportTransferLabel, isNotEmpty);
      expect(en.airportTransferHint, isNotEmpty);
      expect(en.airportDepartureLabel, isNotEmpty);
      expect(en.airportDepartureHint, isNotEmpty);
      expect(en.airportArrivalLabel, isNotEmpty);
      expect(en.airportArrivalHint, isNotEmpty);
      expect(en.flightNumberLabel, isNotEmpty);
      expect(en.flightNumberHint, isNotEmpty);
      expect(en.flightNumberRequired, isNotEmpty);
      expect(en.gateLabel, isNotEmpty);
      expect(en.terminalLabel, isNotEmpty);

      // create_ride_action_buttons
      expect(en.creatingRideLabel, isNotEmpty);
      expect(en.createRideButton, isNotEmpty);
      expect(en.clearFormButton, isNotEmpty);

      // ride_person_card
      expect(en.vehicleInformationLabel, isNotEmpty);
      expect(en.messageButton, isNotEmpty);

      // ride_route_card
      expect(en.routeInformationLabel, isNotEmpty);
      expect(en.pickupTimeLabel, isNotEmpty);
      expect(en.distanceLabel, isNotEmpty);
      expect(en.durationLabel, isNotEmpty);
      expect(en.etaToClientLabel, isNotEmpty);
      expect(en.openInGoogleMapsButton, isNotEmpty);

      // ride_lifecycle_stepper
      expect(en.rideStatusLabel, isNotEmpty);
      expect(en.rideHasBeenCancelledLabel, isNotEmpty);
      expect(en.rideStatusRequestedClientLabel, isNotEmpty);
      expect(en.rideStatusRequestedStaffLabel, isNotEmpty);
      expect(en.rideStatusAssignedEnRouteLabel, isNotEmpty);
      expect(en.rideStatusAssignedLabel, isNotEmpty);
      expect(en.rideStatusAssignedDriverLabel, isNotEmpty);
      expect(en.rideStatusInProgressClientLabel, isNotEmpty);
      expect(en.rideStatusInProgressDriverLabel, isNotEmpty);
      expect(en.rideStatusCompletedLabel, isNotEmpty);
      expect(en.rideStatusCancelledLabel, isNotEmpty);
      expect(en.rideStatusHandedOffLabel, isNotEmpty);

      // create_ride_form_helper
      expect(en.authenticationRequiredError, isNotEmpty);
      expect(en.selectOrCreateClientError, isNotEmpty);
      expect(en.enterClientNameError, isNotEmpty);

      // navigation_utils (_EditRideDialog)
      expect(en.editRideDialogTitle, isNotEmpty);
      expect(en.pickupDateTimeLabel, isNotEmpty);
      expect(en.flightNumberOptionalLabel, isNotEmpty);
      expect(en.notesOptionalLabel, isNotEmpty);
      expect(en.serverErrorMessage('500'), isNotEmpty);
      expect(en.useDispatcherDashboardInfo, isNotEmpty);

      // location_clarification_dialog
      expect(en.updateLocationTitle, isNotEmpty);
      expect(en.tellDriverWhereYouAreLabel, isNotEmpty);
      expect(en.quickSelectLabel, isNotEmpty);
      expect(en.locationQuickMainEntrance, isNotEmpty);
      expect(en.locationQuickBaggageClaim, isNotEmpty);
      expect(en.locationQuickCafe, isNotEmpty);
      expect(en.locationQuickParking, isNotEmpty);
      expect(en.locationQuickInformationDesk, isNotEmpty);
      expect(en.locationQuickSecondFloor, isNotEmpty);
      expect(en.locationQuickExit1, isNotEmpty);
      expect(en.locationQuickExit2, isNotEmpty);
      expect(en.locationQuickOther, isNotEmpty);
      expect(en.orSpecifyExactlyLabel, isNotEmpty);
      expect(en.locationExampleHint, isNotEmpty);
      expect(en.additionalInstructionsLabel, isNotEmpty);
      expect(en.additionalInstructionsExampleHint, isNotEmpty);
      expect(en.specifyLocationError, isNotEmpty);
      expect(en.failedToUpdateLocationError, isNotEmpty);

      // ride_quick_actions
      expect(en.callClientTooltip, isNotEmpty);
      expect(en.navigateTooltip, isNotEmpty);

      // delay_pickup_dialog
      expect(en.delayByHowLongTitle, isNotEmpty);
      expect(en.minutesLabel(15), isNotEmpty);

      // app_header
      expect(en.appSubtitle, isNotEmpty);

      // biometric_button
      expect(en.orLabel, isNotEmpty);
      expect(en.touchIdLabel, isNotEmpty);
      expect(en.biometricsLabel, isNotEmpty);
      expect(en.biometricSetupTitle, isNotEmpty);
      expect(en.biometricSetupMessage, isNotEmpty);
      expect(en.laterButton, isNotEmpty);
      expect(en.enableButton, isNotEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Parity: all new keys present and non-empty in German
  // ────────────────────────────────────────────────────────────────────────────
  group('ride-modules l10n keys — DE parity', () {
    test('all new keys are present and non-empty in German', () async {
      final de = await _l10n('de');

      expect(de.rideCardTimeLabel('10:00'), isNotEmpty);
      expect(de.deleteConfirmationTitle, isNotEmpty);
      expect(de.deleteRideConfirmMessage('A', 'B'), isNotEmpty);
      expect(de.cancelRideDialogTitle, isNotEmpty);
      expect(de.selectCancellationReason, isNotEmpty);
      expect(de.cancellationReasonLabel, isNotEmpty);
      expect(de.cancellationReasonClientRequest, isNotEmpty);
      expect(de.cancellationReasonWeather, isNotEmpty);
      expect(de.cancellationReasonOther, isNotEmpty);
      expect(de.cancellationReasonClientNoShow, isNotEmpty);
      expect(de.cancellationReasonDriverUnavailable, isNotEmpty);
      expect(de.cancellationReasonVehicleIssue, isNotEmpty);
      expect(de.cancellationFeeLabel, isNotEmpty);
      expect(de.rateRideExperienceQuestion, isNotEmpty);
      expect(de.rateRideCommentLabel, isNotEmpty);
      expect(de.rateRideCommentHint, isNotEmpty);
      expect(de.airportTransferLabel, isNotEmpty);
      expect(de.airportTransferHint, isNotEmpty);
      expect(de.airportDepartureLabel, isNotEmpty);
      expect(de.airportDepartureHint, isNotEmpty);
      expect(de.airportArrivalLabel, isNotEmpty);
      expect(de.airportArrivalHint, isNotEmpty);
      expect(de.flightNumberLabel, isNotEmpty);
      expect(de.flightNumberHint, isNotEmpty);
      expect(de.flightNumberRequired, isNotEmpty);
      expect(de.gateLabel, isNotEmpty);
      expect(de.terminalLabel, isNotEmpty);
      expect(de.creatingRideLabel, isNotEmpty);
      expect(de.createRideButton, isNotEmpty);
      expect(de.clearFormButton, isNotEmpty);
      expect(de.vehicleInformationLabel, isNotEmpty);
      expect(de.messageButton, isNotEmpty);
      expect(de.routeInformationLabel, isNotEmpty);
      expect(de.pickupTimeLabel, isNotEmpty);
      expect(de.distanceLabel, isNotEmpty);
      expect(de.durationLabel, isNotEmpty);
      expect(de.etaToClientLabel, isNotEmpty);
      expect(de.openInGoogleMapsButton, isNotEmpty);
      expect(de.rideStatusLabel, isNotEmpty);
      expect(de.rideHasBeenCancelledLabel, isNotEmpty);
      expect(de.rideStatusRequestedClientLabel, isNotEmpty);
      expect(de.rideStatusRequestedStaffLabel, isNotEmpty);
      expect(de.rideStatusAssignedEnRouteLabel, isNotEmpty);
      expect(de.rideStatusAssignedLabel, isNotEmpty);
      expect(de.rideStatusAssignedDriverLabel, isNotEmpty);
      expect(de.rideStatusInProgressClientLabel, isNotEmpty);
      expect(de.rideStatusInProgressDriverLabel, isNotEmpty);
      expect(de.rideStatusCompletedLabel, isNotEmpty);
      expect(de.rideStatusCancelledLabel, isNotEmpty);
      expect(de.rideStatusHandedOffLabel, isNotEmpty);
      expect(de.authenticationRequiredError, isNotEmpty);
      expect(de.selectOrCreateClientError, isNotEmpty);
      expect(de.enterClientNameError, isNotEmpty);
      expect(de.editRideDialogTitle, isNotEmpty);
      expect(de.pickupDateTimeLabel, isNotEmpty);
      expect(de.flightNumberOptionalLabel, isNotEmpty);
      expect(de.notesOptionalLabel, isNotEmpty);
      expect(de.serverErrorMessage('500'), isNotEmpty);
      expect(de.useDispatcherDashboardInfo, isNotEmpty);
      expect(de.updateLocationTitle, isNotEmpty);
      expect(de.tellDriverWhereYouAreLabel, isNotEmpty);
      expect(de.quickSelectLabel, isNotEmpty);
      expect(de.locationQuickMainEntrance, isNotEmpty);
      expect(de.locationQuickBaggageClaim, isNotEmpty);
      expect(de.locationQuickCafe, isNotEmpty);
      expect(de.locationQuickParking, isNotEmpty);
      expect(de.locationQuickInformationDesk, isNotEmpty);
      expect(de.locationQuickSecondFloor, isNotEmpty);
      expect(de.locationQuickExit1, isNotEmpty);
      expect(de.locationQuickExit2, isNotEmpty);
      expect(de.locationQuickOther, isNotEmpty);
      expect(de.orSpecifyExactlyLabel, isNotEmpty);
      expect(de.locationExampleHint, isNotEmpty);
      expect(de.additionalInstructionsLabel, isNotEmpty);
      expect(de.additionalInstructionsExampleHint, isNotEmpty);
      expect(de.specifyLocationError, isNotEmpty);
      expect(de.failedToUpdateLocationError, isNotEmpty);
      expect(de.callClientTooltip, isNotEmpty);
      expect(de.navigateTooltip, isNotEmpty);
      expect(de.delayByHowLongTitle, isNotEmpty);
      expect(de.minutesLabel(15), isNotEmpty);
      expect(de.appSubtitle, isNotEmpty);
      expect(de.orLabel, isNotEmpty);
      expect(de.touchIdLabel, isNotEmpty);
      expect(de.biometricsLabel, isNotEmpty);
      expect(de.biometricSetupTitle, isNotEmpty);
      expect(de.biometricSetupMessage, isNotEmpty);
      expect(de.laterButton, isNotEmpty);
      expect(de.enableButton, isNotEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Parity: all new keys present and non-empty in Ukrainian
  // ────────────────────────────────────────────────────────────────────────────
  group('ride-modules l10n keys — UK parity', () {
    test('all new keys are present and non-empty in Ukrainian', () async {
      final uk = await _l10n('uk');

      expect(uk.rideCardTimeLabel('10:00'), isNotEmpty);
      expect(uk.deleteConfirmationTitle, isNotEmpty);
      expect(uk.deleteRideConfirmMessage('A', 'B'), isNotEmpty);
      expect(uk.cancelRideDialogTitle, isNotEmpty);
      expect(uk.selectCancellationReason, isNotEmpty);
      expect(uk.cancellationReasonLabel, isNotEmpty);
      expect(uk.cancellationReasonClientRequest, isNotEmpty);
      expect(uk.cancellationReasonWeather, isNotEmpty);
      expect(uk.cancellationReasonOther, isNotEmpty);
      expect(uk.cancellationReasonClientNoShow, isNotEmpty);
      expect(uk.cancellationReasonDriverUnavailable, isNotEmpty);
      expect(uk.cancellationReasonVehicleIssue, isNotEmpty);
      expect(uk.cancellationFeeLabel, isNotEmpty);
      expect(uk.rateRideExperienceQuestion, isNotEmpty);
      expect(uk.rateRideCommentLabel, isNotEmpty);
      expect(uk.rateRideCommentHint, isNotEmpty);
      expect(uk.airportTransferLabel, isNotEmpty);
      expect(uk.airportTransferHint, isNotEmpty);
      expect(uk.airportDepartureLabel, isNotEmpty);
      expect(uk.airportDepartureHint, isNotEmpty);
      expect(uk.airportArrivalLabel, isNotEmpty);
      expect(uk.airportArrivalHint, isNotEmpty);
      expect(uk.flightNumberLabel, isNotEmpty);
      expect(uk.flightNumberHint, isNotEmpty);
      expect(uk.flightNumberRequired, isNotEmpty);
      expect(uk.gateLabel, isNotEmpty);
      expect(uk.terminalLabel, isNotEmpty);
      expect(uk.creatingRideLabel, isNotEmpty);
      expect(uk.createRideButton, isNotEmpty);
      expect(uk.clearFormButton, isNotEmpty);
      expect(uk.vehicleInformationLabel, isNotEmpty);
      expect(uk.messageButton, isNotEmpty);
      expect(uk.routeInformationLabel, isNotEmpty);
      expect(uk.pickupTimeLabel, isNotEmpty);
      expect(uk.distanceLabel, isNotEmpty);
      expect(uk.durationLabel, isNotEmpty);
      expect(uk.etaToClientLabel, isNotEmpty);
      expect(uk.openInGoogleMapsButton, isNotEmpty);
      expect(uk.rideStatusLabel, isNotEmpty);
      expect(uk.rideHasBeenCancelledLabel, isNotEmpty);
      expect(uk.rideStatusRequestedClientLabel, isNotEmpty);
      expect(uk.rideStatusRequestedStaffLabel, isNotEmpty);
      expect(uk.rideStatusAssignedEnRouteLabel, isNotEmpty);
      expect(uk.rideStatusAssignedLabel, isNotEmpty);
      expect(uk.rideStatusAssignedDriverLabel, isNotEmpty);
      expect(uk.rideStatusInProgressClientLabel, isNotEmpty);
      expect(uk.rideStatusInProgressDriverLabel, isNotEmpty);
      expect(uk.rideStatusCompletedLabel, isNotEmpty);
      expect(uk.rideStatusCancelledLabel, isNotEmpty);
      expect(uk.rideStatusHandedOffLabel, isNotEmpty);
      expect(uk.authenticationRequiredError, isNotEmpty);
      expect(uk.selectOrCreateClientError, isNotEmpty);
      expect(uk.enterClientNameError, isNotEmpty);
      expect(uk.editRideDialogTitle, isNotEmpty);
      expect(uk.pickupDateTimeLabel, isNotEmpty);
      expect(uk.flightNumberOptionalLabel, isNotEmpty);
      expect(uk.notesOptionalLabel, isNotEmpty);
      expect(uk.serverErrorMessage('500'), isNotEmpty);
      expect(uk.useDispatcherDashboardInfo, isNotEmpty);
      expect(uk.updateLocationTitle, isNotEmpty);
      expect(uk.tellDriverWhereYouAreLabel, isNotEmpty);
      expect(uk.quickSelectLabel, isNotEmpty);
      expect(uk.locationQuickMainEntrance, isNotEmpty);
      expect(uk.locationQuickBaggageClaim, isNotEmpty);
      expect(uk.locationQuickCafe, isNotEmpty);
      expect(uk.locationQuickParking, isNotEmpty);
      expect(uk.locationQuickInformationDesk, isNotEmpty);
      expect(uk.locationQuickSecondFloor, isNotEmpty);
      expect(uk.locationQuickExit1, isNotEmpty);
      expect(uk.locationQuickExit2, isNotEmpty);
      expect(uk.locationQuickOther, isNotEmpty);
      expect(uk.orSpecifyExactlyLabel, isNotEmpty);
      expect(uk.locationExampleHint, isNotEmpty);
      expect(uk.additionalInstructionsLabel, isNotEmpty);
      expect(uk.additionalInstructionsExampleHint, isNotEmpty);
      expect(uk.specifyLocationError, isNotEmpty);
      expect(uk.failedToUpdateLocationError, isNotEmpty);
      expect(uk.callClientTooltip, isNotEmpty);
      expect(uk.navigateTooltip, isNotEmpty);
      expect(uk.delayByHowLongTitle, isNotEmpty);
      expect(uk.minutesLabel(15), isNotEmpty);
      expect(uk.appSubtitle, isNotEmpty);
      expect(uk.orLabel, isNotEmpty);
      expect(uk.touchIdLabel, isNotEmpty);
      expect(uk.biometricsLabel, isNotEmpty);
      expect(uk.biometricSetupTitle, isNotEmpty);
      expect(uk.biometricSetupMessage, isNotEmpty);
      expect(uk.laterButton, isNotEmpty);
      expect(uk.enableButton, isNotEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Semantic spot-checks
  // ────────────────────────────────────────────────────────────────────────────
  group('ride-modules l10n keys — semantic correctness', () {
    test('EN: cancelRideDialogTitle is "Cancel Ride"', () async {
      final en = await _l10n('en');
      expect(en.cancelRideDialogTitle, equals('Cancel Ride'));
    });

    test('EN: rideStatusLabel is "Ride Status"', () async {
      final en = await _l10n('en');
      expect(en.rideStatusLabel, equals('Ride Status'));
    });

    test('EN: delayByHowLongTitle is "Delay by how long?"', () async {
      final en = await _l10n('en');
      expect(en.delayByHowLongTitle, equals('Delay by how long?'));
    });

    test('EN: minutesLabel(5) formats correctly', () async {
      final en = await _l10n('en');
      expect(en.minutesLabel(5), equals('5 minutes'));
    });

    test('EN: deleteRideConfirmMessage formats placeholders', () async {
      final en = await _l10n('en');
      expect(
        en.deleteRideConfirmMessage('Munich HBF', 'Airport'),
        equals('Delete ride Munich HBF → Airport?'),
      );
    });

    test('EN: serverErrorMessage formats statusCode', () async {
      final en = await _l10n('en');
      expect(en.serverErrorMessage('500'), equals('Server error: 500'));
    });

    test('EN: createRideButton is "Create Ride" (not "New Ride")', () async {
      final en = await _l10n('en');
      expect(en.createRideButton, equals('Create Ride'));
    });

    test('DE: cancelRideDialogTitle is "Fahrt stornieren"', () async {
      final de = await _l10n('de');
      expect(de.cancelRideDialogTitle, equals('Fahrt stornieren'));
    });

    test('DE: minutesLabel(30) formats correctly', () async {
      final de = await _l10n('de');
      expect(de.minutesLabel(30), equals('30 Minuten'));
    });

    test('UK: cancelRideDialogTitle is "Скасувати поїздку"', () async {
      final uk = await _l10n('uk');
      expect(uk.cancelRideDialogTitle, equals('Скасувати поїздку'));
    });

    test('UK: rideStatusLabel is "Статус поїздки"', () async {
      final uk = await _l10n('uk');
      expect(uk.rideStatusLabel, equals('Статус поїздки'));
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // No-duplicate check: shared keys must not have been redefined
  // ────────────────────────────────────────────────────────────────────────────
  group('ride-modules l10n keys — no synonym duplicates', () {
    test(
      'EN: cancel, confirm, save, delete are still the shared keys',
      () async {
        final en = await _l10n('en');
        expect(en.cancel, equals('Cancel'));
        expect(en.confirm, equals('Confirm'));
        expect(en.save, equals('Save'));
        expect(en.delete, equals('Delete'));
        expect(en.call, equals('Call'));
        expect(en.send, equals('Send'));
        expect(en.start, equals('Start'));
        expect(en.completeRideButton, equals('Complete'));
        expect(en.fromLabel, equals('From'));
        expect(en.toLabel, equals('To'));
        expect(en.roleDriver, equals('Driver'));
        expect(en.roleClient, equals('Client'));
        expect(en.cancelled, equals('Cancelled'));
      },
    );
  });
}
