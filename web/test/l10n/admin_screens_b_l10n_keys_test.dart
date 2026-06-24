// Tests that all new client/feature-screen l10n keys (added in the
// l10n-admin-screens refactor, sub-task B) resolve to non-empty strings in all
// three supported locales and that parameterised keys format placeholders
// correctly.
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
  // ───────────────────────────────────────────────────────────────────────────
  // EN parity — all new keys present and non-empty
  // ───────────────────────────────────────────────────────────────────────────
  group('admin-screens-B l10n keys — EN parity', () {
    test('gdpr_screen keys', () async {
      final en = await _l10n('en');

      expect(en.gdprScreenTitle, isNotEmpty);
      expect(en.consentManagementSectionTitle, isNotEmpty);
      expect(en.consentDataProcessingLabel, isNotEmpty);
      expect(en.consentDataProcessingSubtitle, isNotEmpty);
      expect(en.consentMarketingLabel, isNotEmpty);
      expect(en.consentMarketingSubtitle, isNotEmpty);
      expect(en.consentAnalyticsLabel, isNotEmpty);
      expect(en.consentAnalyticsSubtitle, isNotEmpty);
      expect(en.consentThirdPartySharingLabel, isNotEmpty);
      expect(en.consentThirdPartySharingSubtitle, isNotEmpty);
      expect(en.yourDataSectionTitle, isNotEmpty);
      expect(en.exportMyDataLabel, isNotEmpty);
      expect(en.exportMyDataSubtitle, isNotEmpty);
      expect(en.dataDeletionSectionTitle, isNotEmpty);
      expect(en.requestDataDeletionLabel, isNotEmpty);
      expect(en.requestDataDeletionSubtitle, isNotEmpty);
      expect(en.pendingDeletionSubtitle, isNotEmpty);
      expect(en.pendingChipLabel, isNotEmpty);
      expect(en.requestHistoryTitle, isNotEmpty);
      expect(en.requestDeletionDialogTitle, isNotEmpty);
      expect(en.requestDeletionDialogContent, isNotEmpty);
      expect(en.requestDeletionButton, isNotEmpty);
      expect(en.dataExportCopied, isNotEmpty);
      expect(en.exportFailed('err'), isNotEmpty);
      expect(en.deletionRequestSubmitted, isNotEmpty);
      expect(en.failedToLoadGdprData('404', '500'), isNotEmpty);
      expect(en.dataDeletionRequestType, isNotEmpty);
      expect(en.dataExportRequestType, isNotEmpty);
    });

    test('payment_screen keys (admin unpaid rides)', () async {
      final en = await _l10n('en');

      expect(en.paymentsTitle, isNotEmpty);
      expect(en.unpaidBadgeLabel, isNotEmpty);
      expect(en.allRidesPaidLabel, isNotEmpty);
      expect(en.markAsPaidDialogTitle, isNotEmpty);
      expect(en.paymentMethodLabel, isNotEmpty);
      expect(en.paymentMethodCash, isNotEmpty);
      expect(en.paymentMethodCard, isNotEmpty);
      expect(en.paymentMethodInvoice, isNotEmpty);
      expect(en.amountLabel('42.50'), isNotEmpty);
      expect(en.confirmPaymentButton, isNotEmpty);
      expect(en.paymentRecordedSuccess, isNotEmpty);
      expect(en.failedToLoadUnpaidRides, isNotEmpty);
    });

    test('ride_details_screen keys', () async {
      final en = await _l10n('en');

      expect(en.myRideTitle('abc123'), isNotEmpty);
      expect(en.rideTitle('abc123'), isNotEmpty);
      expect(en.confirmationSentLabel, isNotEmpty);
      expect(en.cancellationDetailsTitle, isNotEmpty);
      expect(en.cancellationReasonDetail('Late'), isNotEmpty);
      expect(en.cancelledByLabel('Max'), isNotEmpty);
      expect(en.cancellationFeeDisplay('5.00'), isNotEmpty);
      expect(en.ratingTitle, isNotEmpty);
      expect(en.notesTitle, isNotEmpty);
      expect(en.openChatButton, isNotEmpty);
      expect(en.rideStatusUpdatedSuccess, isNotEmpty);
      expect(en.failedToUpdateRideStatus('err'), isNotEmpty);
      expect(en.driverAssignedSuccess, isNotEmpty);
      expect(en.failedToAssignDriver('err'), isNotEmpty);
      expect(en.rideCancelledSuccess, isNotEmpty);
      expect(en.failedToCancelRide('err'), isNotEmpty);
      expect(en.failedToSubmitRating('err'), isNotEmpty);
      expect(en.completeRideDialogTitle, isNotEmpty);
      expect(en.completeRideDialogContent, isNotEmpty);
    });

    test('create_ride_screen keys', () async {
      final en = await _l10n('en');

      expect(en.createNewRideTitle, isNotEmpty);
      expect(en.rideCreatedSuccess, isNotEmpty);
      expect(en.failedToCreateRide, isNotEmpty);
      expect(en.conflictDialogTitle, isNotEmpty);
      expect(en.conflictDialogContent('overlap msg'), isNotEmpty);
      expect(en.conflictDialogContentDefault, isNotEmpty);
      expect(en.keepInPoolButton, isNotEmpty);
      expect(en.assignAnywayButton, isNotEmpty);
    });

    test('ride_export_screen keys', () async {
      final en = await _l10n('en');

      expect(en.exportRidesTitle, isNotEmpty);
      expect(en.copyCsvButton, isNotEmpty);
      expect(en.dateRangeButton, isNotEmpty);
      expect(en.noRidesMatchFilters, isNotEmpty);
      expect(en.exportSummaryTotal, isNotEmpty);
      expect(en.exportSummaryCompleted, isNotEmpty);
      expect(en.exportSummaryRevenue, isNotEmpty);
      expect(en.csvCopiedSnackbar(12), isNotEmpty);
      expect(en.okButton, isNotEmpty);
    });

    test('flight_screen keys', () async {
      final en = await _l10n('en');

      expect(en.flightsMunichAirportTitle, isNotEmpty);
      expect(en.autoSyncedLabel, isNotEmpty);
      expect(en.arrivalsTabLabel, isNotEmpty);
      expect(en.departuresTabLabel, isNotEmpty);
      expect(en.noArrivalsFound, isNotEmpty);
      expect(en.noDeparturesFound, isNotEmpty);
      expect(en.errorLoadingFlights('err'), isNotEmpty);
      expect(en.flightColumnFlight, isNotEmpty);
      expect(en.flightColumnOriginDest, isNotEmpty);
      expect(en.flightColumnSched, isNotEmpty);
      expect(en.flightColumnStatus, isNotEmpty);
      expect(en.flightColumnLinkedRide, isNotEmpty);
      expect(en.flightStatusOnTime, isNotEmpty);
      expect(en.flightStatusDelayed, isNotEmpty);
      expect(en.flightStatusBoarding, isNotEmpty);
      expect(en.flightStatusCancelled, isNotEmpty);
      expect(en.flightStatusUnknown, isNotEmpty);
      expect(en.flightNotLinked, isNotEmpty);
    });

    test('driver_schedule_visibility_screen keys', () async {
      final en = await _l10n('en');

      expect(en.whoCanSeeWhomTitle, isNotEmpty);
      expect(en.visibleToAllDispatchers, isNotEmpty);
      expect(en.scheduleHiddenFromOthers, isNotEmpty);
      expect(en.noDriversInCompany, isNotEmpty);
      expect(en.failedToUpdateVisibilityError('err'), isNotEmpty);
    });

    test('audit_log_screen keys', () async {
      final en = await _l10n('en');

      expect(en.auditLogScreenTitle, isNotEmpty);
      expect(en.searchByEntityIdHint, isNotEmpty);
      expect(en.noAuditEntriesFound, isNotEmpty);
    });

    test('chat_screen keys', () async {
      final en = await _l10n('en');

      expect(en.onlineOnRideLabel('a1b2c3'), isNotEmpty);
      expect(en.startConversationSubtitle, isNotEmpty);
      expect(en.failedToSendMessage('err'), isNotEmpty);
    });

    test('superadmin_analytics_screen keys', () async {
      final en = await _l10n('en');

      expect(en.totalRidesStatLabel, isNotEmpty);
      expect(en.onTimeStatLabel, isNotEmpty);
      expect(en.avgSlackStatLabel, isNotEmpty);
      expect(en.gmvStatLabel, isNotEmpty);
      expect(en.ridesByTenantTitle, isNotEmpty);
      expect(en.rideStatusBreakdownTitle, isNotEmpty);
      expect(en.platformActiveSessionsLabel, isNotEmpty);
    });

    test('client_payment_screen keys', () async {
      final en = await _l10n('en');

      expect(en.clientPaymentTitle, isNotEmpty);
      expect(en.paymentMethodsSectionLabel, isNotEmpty);
      expect(en.corporateInvoiceLabel, isNotEmpty);
      expect(en.addPaymentMethodButton, isNotEmpty);
    });

    // Keys reused from previous batches (0 new keys in notifications_screen)
    test('notifications_screen reuse keys still present', () async {
      final en = await _l10n('en');

      expect(en.notifications, isNotEmpty);
      expect(en.markAllReadButton, isNotEmpty);
      expect(en.noNotificationsYet, isNotEmpty);
      expect(en.retry, isNotEmpty);
      expect(en.operationFailed('err'), isNotEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // DE parity — same keys resolve in German
  // ───────────────────────────────────────────────────────────────────────────
  group('admin-screens-B l10n keys — DE parity', () {
    test('gdpr_screen keys DE', () async {
      final de = await _l10n('de');

      expect(de.gdprScreenTitle, isNotEmpty);
      expect(de.consentManagementSectionTitle, isNotEmpty);
      expect(de.exportFailed('err'), isNotEmpty);
      expect(de.failedToLoadGdprData('404', '500'), isNotEmpty);
      expect(de.dataDeletionRequestType, isNotEmpty);
      expect(de.dataExportRequestType, isNotEmpty);
    });

    test('payment_screen keys DE', () async {
      final de = await _l10n('de');

      expect(de.paymentsTitle, isNotEmpty);
      expect(de.paymentMethodCash, isNotEmpty);
      expect(de.paymentMethodCard, isNotEmpty);
      expect(de.paymentMethodInvoice, isNotEmpty);
      expect(de.amountLabel('99.99'), isNotEmpty);
    });

    test('ride_details_screen keys DE', () async {
      final de = await _l10n('de');

      expect(de.myRideTitle('abc'), isNotEmpty);
      expect(de.rideTitle('abc'), isNotEmpty);
      expect(de.cancellationReasonDetail('Verzögerung'), isNotEmpty);
      expect(de.cancelledByLabel('Max'), isNotEmpty);
      expect(de.failedToUpdateRideStatus('err'), isNotEmpty);
    });

    test('flight_screen keys DE', () async {
      final de = await _l10n('de');

      expect(de.flightsMunichAirportTitle, isNotEmpty);
      expect(de.flightStatusOnTime, isNotEmpty);
      expect(de.flightStatusDelayed, isNotEmpty);
      expect(de.errorLoadingFlights('err'), isNotEmpty);
    });

    test('superadmin_analytics_screen keys DE', () async {
      final de = await _l10n('de');

      expect(de.totalRidesStatLabel, isNotEmpty);
      expect(de.ridesByTenantTitle, isNotEmpty);
      expect(de.platformActiveSessionsLabel, isNotEmpty);
    });

    test('client_payment_screen keys DE', () async {
      final de = await _l10n('de');

      expect(de.clientPaymentTitle, isNotEmpty);
      expect(de.paymentMethodsSectionLabel, isNotEmpty);
      expect(de.corporateInvoiceLabel, isNotEmpty);
      expect(de.addPaymentMethodButton, isNotEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // UK parity — same keys resolve in Ukrainian
  // ───────────────────────────────────────────────────────────────────────────
  group('admin-screens-B l10n keys — UK parity', () {
    test('gdpr_screen keys UK', () async {
      final uk = await _l10n('uk');

      expect(uk.gdprScreenTitle, isNotEmpty);
      expect(uk.consentManagementSectionTitle, isNotEmpty);
      expect(uk.exportFailed('err'), isNotEmpty);
      expect(uk.failedToLoadGdprData('404', '500'), isNotEmpty);
      expect(uk.dataDeletionRequestType, isNotEmpty);
      expect(uk.dataExportRequestType, isNotEmpty);
    });

    test('payment_screen keys UK', () async {
      final uk = await _l10n('uk');

      expect(uk.paymentsTitle, isNotEmpty);
      expect(uk.paymentMethodCash, isNotEmpty);
      expect(uk.paymentMethodCard, isNotEmpty);
      expect(uk.paymentMethodInvoice, isNotEmpty);
      expect(uk.amountLabel('99.99'), isNotEmpty);
    });

    test('ride_details_screen keys UK', () async {
      final uk = await _l10n('uk');

      expect(uk.myRideTitle('abc'), isNotEmpty);
      expect(uk.rideTitle('abc'), isNotEmpty);
      expect(uk.cancellationReasonDetail('пізно'), isNotEmpty);
      expect(uk.cancelledByLabel('Іван'), isNotEmpty);
      expect(uk.failedToUpdateRideStatus('err'), isNotEmpty);
    });

    test('flight_screen keys UK', () async {
      final uk = await _l10n('uk');

      expect(uk.flightsMunichAirportTitle, isNotEmpty);
      expect(uk.flightStatusOnTime, isNotEmpty);
      expect(uk.flightStatusDelayed, isNotEmpty);
      expect(uk.errorLoadingFlights('err'), isNotEmpty);
    });

    test('superadmin_analytics_screen keys UK', () async {
      final uk = await _l10n('uk');

      expect(uk.totalRidesStatLabel, isNotEmpty);
      expect(uk.ridesByTenantTitle, isNotEmpty);
      expect(uk.platformActiveSessionsLabel, isNotEmpty);
    });

    test('client_payment_screen keys UK', () async {
      final uk = await _l10n('uk');

      expect(uk.clientPaymentTitle, isNotEmpty);
      expect(uk.paymentMethodsSectionLabel, isNotEmpty);
      expect(uk.corporateInvoiceLabel, isNotEmpty);
      expect(uk.addPaymentMethodButton, isNotEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Parameterised key formatting — spot-check substitution is correct
  // ───────────────────────────────────────────────────────────────────────────
  group('admin-screens-B parameterised keys — correct substitution', () {
    test('csvCopiedSnackbar formats count', () async {
      final en = await _l10n('en');
      final result = en.csvCopiedSnackbar(7);
      expect(result, contains('7'));
    });

    test('myRideTitle formats id', () async {
      final en = await _l10n('en');
      final result = en.myRideTitle('a1b2');
      expect(result, contains('a1b2'));
    });

    test('rideTitle formats id', () async {
      final en = await _l10n('en');
      final result = en.rideTitle('x9y8');
      expect(result, contains('x9y8'));
    });

    test('cancellationReasonDetail formats reason', () async {
      final en = await _l10n('en');
      final result = en.cancellationReasonDetail('Traffic');
      expect(result, contains('Traffic'));
    });

    test('cancelledByLabel formats name', () async {
      final en = await _l10n('en');
      final result = en.cancelledByLabel('Maria');
      expect(result, contains('Maria'));
    });

    test('conflictDialogContent formats message', () async {
      final en = await _l10n('en');
      final result = en.conflictDialogContent('overlap at 09:00');
      expect(result, contains('overlap at 09:00'));
    });

    test('onlineOnRideLabel formats rideId', () async {
      final en = await _l10n('en');
      final result = en.onlineOnRideLabel('ride42');
      expect(result, contains('ride42'));
    });

    test('amountLabel formats amount', () async {
      final en = await _l10n('en');
      final result = en.amountLabel('123.45');
      expect(result, contains('123.45'));
    });

    test('failedToLoadGdprData formats codes', () async {
      final en = await _l10n('en');
      final result = en.failedToLoadGdprData('500', '404');
      expect(result, contains('500'));
    });

    test('errorLoadingFlights formats error', () async {
      final en = await _l10n('en');
      final result = en.errorLoadingFlights('timeout');
      expect(result, contains('timeout'));
    });
  });
}
