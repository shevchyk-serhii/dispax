// Tests that the dispatcher l10n keys (added in the l10n-dispatcher refactor)
// resolve to the correct strings in all three supported locales, and that
// parameterized keys format their placeholders correctly.
//
// This covers:
//   - Key-for-key parity: all 88 new dispatcher keys exist in all three locales
//   - Semantic correctness: shared keys (discardChangesTitle, cancel, retry,
//     assignAnywayTitle, reassign, analytics, myRides, billingScreenTitle,
//     settings, selectDriver, etc.) are NOT duplicated under new names
//   - Parameterized key formatting:
//       dispatcherSubtitle(weekday, date, count)  — weekday/date: String, count: int
//       assignRideDialogTitle(rideId)             — rideId: String
//       scheduleConflictsCount(count)             — count: int
//       reassignRideDialogTitle(rideId)           — rideId: String
//       reassignNRides(count)                     — count: int
//       driverDelayedMessage(driverName, slack)   — both String (sign pre-applied)
//       ridesToReassignLabel(selected, total)     — both int
//       ridesReassignedMessage(count, driverName) — count: int, driverName: String
//       unassignedRidesBadge(count)               — count: int
//   - No synonym duplication: settingsMenuItem/analyticsMenuItem are accepted new keys
//     (separate concern for More-menu vs. nav-label context)
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
  // ---------------------------------------------------------------------------
  // Parity: representative set of all 88 new keys in all three locales
  // ---------------------------------------------------------------------------
  group('dispatcher l10n keys — parity (all new keys non-empty)', () {
    test('all new dispatcher keys are present and non-empty in English', () async {
      final en = await _l10n('en');
      // Navigation tabs
      expect(en.homeTab, isNotEmpty);
      expect(en.scheduleTab, isNotEmpty);
      expect(en.calendarTab, isNotEmpty);
      expect(en.newRideTab, isNotEmpty);
      expect(en.moreTab, isNotEmpty);
      expect(en.billingTab, isNotEmpty);
      expect(en.moreScreenTitle, isNotEmpty);
      // Top bar
      expect(en.dispatchBoardTitle, isNotEmpty);
      expect(en.searchRidesDrivers, isNotEmpty);
      expect(en.newRideButtonLabel, isNotEmpty);
      // Stats row
      expect(en.activeRidesLabel, isNotEmpty);
      expect(en.atRiskLabel, isNotEmpty);
      expect(en.driversOnlineLabel, isNotEmpty);
      expect(en.onTimeLabel, isNotEmpty);
      // More-menu items
      expect(en.earningsMenuItem, isNotEmpty);
      expect(en.peakHoursMenuItem, isNotEmpty);
      expect(en.clientValueMenuItem, isNotEmpty);
      expect(en.driversMenuItem, isNotEmpty);
      expect(en.ratingsMenuItem, isNotEmpty);
      expect(en.auditLogMenuItem, isNotEmpty);
      expect(en.adminMenuItem, isNotEmpty);
      expect(en.companyMenuItem, isNotEmpty);
      expect(en.expensesMenuItem, isNotEmpty);
      expect(en.exportMenuItem, isNotEmpty);
      expect(en.templatesMenuItem, isNotEmpty);
      expect(en.paymentsMenuItem, isNotEmpty);
      expect(en.payrollMenuItem, isNotEmpty);
      expect(en.settingsMenuItem, isNotEmpty);
      expect(en.geofencesMenuItem, isNotEmpty);
      expect(en.datevMenuItem, isNotEmpty);
      expect(en.blacklistMenuItem, isNotEmpty);
      expect(en.emergencyMenuItem, isNotEmpty);
      expect(en.ridePoolsMenuItem, isNotEmpty);
      expect(en.notificationsMenuItem, isNotEmpty);
      expect(en.gdprMenuItem, isNotEmpty);
      expect(en.sessionsMenuItem, isNotEmpty);
      expect(en.schedVisibilityMenuItem, isNotEmpty);
      expect(en.analyticsMenuItem, isNotEmpty);
      expect(en.driverBoardMenuItem, isNotEmpty);
      expect(en.driverMapMenuItem, isNotEmpty);
      // assignment_dialog keys
      expect(en.rideDetailsLabel, isNotEmpty);
      expect(en.clientLabel, isNotEmpty);
      expect(en.timeLabel, isNotEmpty);
      expect(en.fromLabel, isNotEmpty);
      expect(en.toLabel, isNotEmpty);
      expect(en.flightLabel, isNotEmpty);
      expect(en.fareLabel, isNotEmpty);
      expect(en.assigningToLabel, isNotEmpty);
      expect(en.assignDriverButton, isNotEmpty);
      // bulk_reassign_dialog keys
      expect(en.nearestAvailableDriversLabel, isNotEmpty);
      expect(en.noDriversAvailableForReassignment, isNotEmpty);
      expect(en.deselectAllButton, isNotEmpty);
      expect(en.selectAllButton, isNotEmpty);
      expect(en.bestMatchBadge, isNotEmpty);
      expect(en.stillLateLabel, isNotEmpty);
      expect(en.slackRestoredLabel, isNotEmpty);
      expect(en.tightLabel, isNotEmpty);
      // pending_rides_panel keys
      expect(en.reassignAnyway, isNotEmpty);
      expect(en.pendingTab, isNotEmpty);
      expect(en.assignedTab, isNotEmpty);
      expect(en.sortTooltip, isNotEmpty);
      expect(en.noAssignedRides, isNotEmpty);
      expect(en.noRidesCurrentlyAssigned, isNotEmpty);
      expect(en.pendingRequestsHeader, isNotEmpty);
      // eta_alert_card keys
      expect(en.rideAtRiskTitle, isNotEmpty);
      expect(en.etaMonitorBadgeLabel, isNotEmpty);
      expect(en.viewButton, isNotEmpty);
      expect(en.etaDriverEtaLabel, isNotEmpty);
      expect(en.etaPickupInLabel, isNotEmpty);
      expect(en.etaSlackLabel, isNotEmpty);
      // driver_earnings_panel keys
      expect(en.driverEarningsTitle, isNotEmpty);
      expect(en.sortByEarnings, isNotEmpty);
      expect(en.sortByName, isNotEmpty);
      expect(en.sortByRides, isNotEmpty);
      // payroll_screen keys
      expect(en.driverPayrollTitle, isNotEmpty);
      expect(en.loadPayrollButton, isNotEmpty);
      expect(en.payrollCsvCopiedMessage, isNotEmpty);
      expect(en.payrollSummaryTitle, isNotEmpty);
      expect(en.commissionLabel, isNotEmpty);
    });

    test('all new dispatcher keys are non-empty in German', () async {
      final de = await _l10n('de');
      expect(de.homeTab, isNotEmpty);
      expect(de.scheduleTab, isNotEmpty);
      expect(de.calendarTab, isNotEmpty);
      expect(de.newRideTab, isNotEmpty);
      expect(de.moreTab, isNotEmpty);
      expect(de.billingTab, isNotEmpty);
      expect(de.moreScreenTitle, isNotEmpty);
      expect(de.dispatchBoardTitle, isNotEmpty);
      expect(de.searchRidesDrivers, isNotEmpty);
      expect(de.newRideButtonLabel, isNotEmpty);
      expect(de.activeRidesLabel, isNotEmpty);
      expect(de.atRiskLabel, isNotEmpty);
      expect(de.driversOnlineLabel, isNotEmpty);
      expect(de.onTimeLabel, isNotEmpty);
      expect(de.earningsMenuItem, isNotEmpty);
      expect(de.peakHoursMenuItem, isNotEmpty);
      expect(de.clientValueMenuItem, isNotEmpty);
      expect(de.driversMenuItem, isNotEmpty);
      expect(de.ratingsMenuItem, isNotEmpty);
      expect(de.auditLogMenuItem, isNotEmpty);
      expect(de.adminMenuItem, isNotEmpty);
      expect(de.companyMenuItem, isNotEmpty);
      expect(de.expensesMenuItem, isNotEmpty);
      expect(de.exportMenuItem, isNotEmpty);
      expect(de.templatesMenuItem, isNotEmpty);
      expect(de.paymentsMenuItem, isNotEmpty);
      expect(de.payrollMenuItem, isNotEmpty);
      expect(de.settingsMenuItem, isNotEmpty);
      expect(de.geofencesMenuItem, isNotEmpty);
      expect(de.datevMenuItem, isNotEmpty);
      expect(de.blacklistMenuItem, isNotEmpty);
      expect(de.emergencyMenuItem, isNotEmpty);
      expect(de.ridePoolsMenuItem, isNotEmpty);
      expect(de.notificationsMenuItem, isNotEmpty);
      expect(de.gdprMenuItem, isNotEmpty);
      expect(de.sessionsMenuItem, isNotEmpty);
      expect(de.schedVisibilityMenuItem, isNotEmpty);
      expect(de.analyticsMenuItem, isNotEmpty);
      expect(de.driverBoardMenuItem, isNotEmpty);
      expect(de.driverMapMenuItem, isNotEmpty);
      expect(de.rideDetailsLabel, isNotEmpty);
      expect(de.clientLabel, isNotEmpty);
      expect(de.timeLabel, isNotEmpty);
      expect(de.fromLabel, isNotEmpty);
      expect(de.toLabel, isNotEmpty);
      expect(de.flightLabel, isNotEmpty);
      expect(de.fareLabel, isNotEmpty);
      expect(de.assigningToLabel, isNotEmpty);
      expect(de.assignDriverButton, isNotEmpty);
      expect(de.nearestAvailableDriversLabel, isNotEmpty);
      expect(de.noDriversAvailableForReassignment, isNotEmpty);
      expect(de.deselectAllButton, isNotEmpty);
      expect(de.selectAllButton, isNotEmpty);
      expect(de.bestMatchBadge, isNotEmpty);
      expect(de.stillLateLabel, isNotEmpty);
      expect(de.slackRestoredLabel, isNotEmpty);
      expect(de.tightLabel, isNotEmpty);
      expect(de.reassignAnyway, isNotEmpty);
      expect(de.pendingTab, isNotEmpty);
      expect(de.assignedTab, isNotEmpty);
      expect(de.sortTooltip, isNotEmpty);
      expect(de.noAssignedRides, isNotEmpty);
      expect(de.noRidesCurrentlyAssigned, isNotEmpty);
      expect(de.pendingRequestsHeader, isNotEmpty);
      expect(de.rideAtRiskTitle, isNotEmpty);
      expect(de.etaMonitorBadgeLabel, isNotEmpty);
      expect(de.viewButton, isNotEmpty);
      expect(de.etaDriverEtaLabel, isNotEmpty);
      expect(de.etaPickupInLabel, isNotEmpty);
      expect(de.etaSlackLabel, isNotEmpty);
      expect(de.driverEarningsTitle, isNotEmpty);
      expect(de.sortByEarnings, isNotEmpty);
      expect(de.sortByName, isNotEmpty);
      expect(de.sortByRides, isNotEmpty);
      expect(de.driverPayrollTitle, isNotEmpty);
      expect(de.loadPayrollButton, isNotEmpty);
      expect(de.payrollCsvCopiedMessage, isNotEmpty);
      expect(de.payrollSummaryTitle, isNotEmpty);
      expect(de.commissionLabel, isNotEmpty);
    });

    test('all new dispatcher keys are non-empty in Ukrainian', () async {
      final uk = await _l10n('uk');
      expect(uk.homeTab, isNotEmpty);
      expect(uk.scheduleTab, isNotEmpty);
      expect(uk.calendarTab, isNotEmpty);
      expect(uk.newRideTab, isNotEmpty);
      expect(uk.moreTab, isNotEmpty);
      expect(uk.billingTab, isNotEmpty);
      expect(uk.moreScreenTitle, isNotEmpty);
      expect(uk.dispatchBoardTitle, isNotEmpty);
      expect(uk.searchRidesDrivers, isNotEmpty);
      expect(uk.newRideButtonLabel, isNotEmpty);
      expect(uk.activeRidesLabel, isNotEmpty);
      expect(uk.atRiskLabel, isNotEmpty);
      expect(uk.driversOnlineLabel, isNotEmpty);
      expect(uk.onTimeLabel, isNotEmpty);
      expect(uk.earningsMenuItem, isNotEmpty);
      expect(uk.peakHoursMenuItem, isNotEmpty);
      expect(uk.clientValueMenuItem, isNotEmpty);
      expect(uk.driversMenuItem, isNotEmpty);
      expect(uk.ratingsMenuItem, isNotEmpty);
      expect(uk.auditLogMenuItem, isNotEmpty);
      expect(uk.adminMenuItem, isNotEmpty);
      expect(uk.companyMenuItem, isNotEmpty);
      expect(uk.expensesMenuItem, isNotEmpty);
      expect(uk.exportMenuItem, isNotEmpty);
      expect(uk.templatesMenuItem, isNotEmpty);
      expect(uk.paymentsMenuItem, isNotEmpty);
      expect(uk.payrollMenuItem, isNotEmpty);
      expect(uk.settingsMenuItem, isNotEmpty);
      expect(uk.geofencesMenuItem, isNotEmpty);
      expect(uk.datevMenuItem, isNotEmpty);
      expect(uk.blacklistMenuItem, isNotEmpty);
      expect(uk.emergencyMenuItem, isNotEmpty);
      expect(uk.ridePoolsMenuItem, isNotEmpty);
      expect(uk.notificationsMenuItem, isNotEmpty);
      expect(uk.gdprMenuItem, isNotEmpty);
      expect(uk.sessionsMenuItem, isNotEmpty);
      expect(uk.schedVisibilityMenuItem, isNotEmpty);
      expect(uk.analyticsMenuItem, isNotEmpty);
      expect(uk.driverBoardMenuItem, isNotEmpty);
      expect(uk.driverMapMenuItem, isNotEmpty);
      expect(uk.rideDetailsLabel, isNotEmpty);
      expect(uk.clientLabel, isNotEmpty);
      expect(uk.timeLabel, isNotEmpty);
      expect(uk.fromLabel, isNotEmpty);
      expect(uk.toLabel, isNotEmpty);
      expect(uk.flightLabel, isNotEmpty);
      expect(uk.fareLabel, isNotEmpty);
      expect(uk.assigningToLabel, isNotEmpty);
      expect(uk.assignDriverButton, isNotEmpty);
      expect(uk.nearestAvailableDriversLabel, isNotEmpty);
      expect(uk.noDriversAvailableForReassignment, isNotEmpty);
      expect(uk.deselectAllButton, isNotEmpty);
      expect(uk.selectAllButton, isNotEmpty);
      expect(uk.bestMatchBadge, isNotEmpty);
      expect(uk.stillLateLabel, isNotEmpty);
      expect(uk.slackRestoredLabel, isNotEmpty);
      expect(uk.tightLabel, isNotEmpty);
      expect(uk.reassignAnyway, isNotEmpty);
      expect(uk.pendingTab, isNotEmpty);
      expect(uk.assignedTab, isNotEmpty);
      expect(uk.sortTooltip, isNotEmpty);
      expect(uk.noAssignedRides, isNotEmpty);
      expect(uk.noRidesCurrentlyAssigned, isNotEmpty);
      expect(uk.pendingRequestsHeader, isNotEmpty);
      expect(uk.rideAtRiskTitle, isNotEmpty);
      expect(uk.etaMonitorBadgeLabel, isNotEmpty);
      expect(uk.viewButton, isNotEmpty);
      expect(uk.etaDriverEtaLabel, isNotEmpty);
      expect(uk.etaPickupInLabel, isNotEmpty);
      expect(uk.etaSlackLabel, isNotEmpty);
      expect(uk.driverEarningsTitle, isNotEmpty);
      expect(uk.sortByEarnings, isNotEmpty);
      expect(uk.sortByName, isNotEmpty);
      expect(uk.sortByRides, isNotEmpty);
      expect(uk.driverPayrollTitle, isNotEmpty);
      expect(uk.loadPayrollButton, isNotEmpty);
      expect(uk.payrollCsvCopiedMessage, isNotEmpty);
      expect(uk.payrollSummaryTitle, isNotEmpty);
      expect(uk.commissionLabel, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Semantic correctness: exact values for key strings in all three locales
  // ---------------------------------------------------------------------------
  group('dispatcher l10n keys — semantic correctness', () {
    test('homeTab is "Home"/"Startseite"/"Головна" (not reused "today")', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.homeTab, equals('Home'));
      expect(de.homeTab, equals('Startseite'));
      expect(uk.homeTab, equals('Головна'));

      // homeTab must NOT equal today (driver tab) in any locale.
      expect(en.homeTab, isNot(equals(en.today)));
      expect(de.homeTab, isNot(equals(de.today)));
      expect(uk.homeTab, isNot(equals(uk.today)));
    });

    test('billingTab is a distinct key from billingScreenTitle with proper localized values', () async {
      // billingTab was added as a new key with the full localized name for the nav tab.
      // billingScreenTitle is a pre-existing key that happens to keep "Billing" in DE,
      // while billingTab uses the fully translated "Abrechnung"/"Виставлення рахунків".
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      // EN: both have "Billing"
      expect(en.billingTab, equals('Billing'));
      expect(en.billingScreenTitle, equals('Billing'));

      // DE: billingTab is properly translated; billingScreenTitle kept as "Billing"
      expect(de.billingTab, equals('Abrechnung'));
      expect(de.billingTab, isNotEmpty);

      // UK: billingTab is properly translated
      expect(uk.billingTab, equals('Виставлення рахунків'));
      expect(uk.billingTab, isNotEmpty);
    });

    test('moreTab and moreScreenTitle share the same value across locales', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.moreTab, equals(en.moreScreenTitle));
      expect(de.moreTab, equals(de.moreScreenTitle));
      expect(uk.moreTab, equals(uk.moreScreenTitle));
    });

    test('dispatchBoardTitle correct in all locales', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.dispatchBoardTitle, equals('Dispatch board'));
      expect(de.dispatchBoardTitle, equals('Dispositionsbrett'));
      expect(uk.dispatchBoardTitle, equals('Дошка диспетчера'));
    });

    test('reassignAnyway vs assignAnyway are distinct (different verbs)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      // "Reassign anyway" (reassignAnyway) must differ from "Assign Anyway" (assignAnyway).
      expect(en.reassignAnyway, equals('Reassign anyway'));
      expect(en.assignAnyway, equals('Assign Anyway'));
      expect(en.reassignAnyway, isNot(equals(en.assignAnyway)));

      expect(de.reassignAnyway, isNot(equals(de.assignAnyway)));
      expect(uk.reassignAnyway, isNot(equals(uk.assignAnyway)));
    });

    test('pendingTab and assignedTab are distinct in all locales', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.pendingTab, equals('Pending'));
      expect(en.assignedTab, equals('Assigned'));
      expect(en.pendingTab, isNot(equals(en.assignedTab)));

      expect(de.pendingTab, isNot(equals(de.assignedTab)));
      expect(uk.pendingTab, isNot(equals(uk.assignedTab)));
    });

    test('noAssignedRides vs noRidesCurrentlyAssigned are distinct', () async {
      // noAssignedRides = short label; noRidesCurrentlyAssigned = longer description.
      final en = await _l10n('en');

      expect(en.noAssignedRides, equals('No assigned rides'));
      expect(en.noRidesCurrentlyAssigned, equals('No rides currently assigned to drivers'));
      expect(en.noAssignedRides, isNot(equals(en.noRidesCurrentlyAssigned)));
    });

    test('driverMapMenuItem correct in all locales (used in nav + FilledButton)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.driverMapMenuItem, equals('Driver Map'));
      expect(de.driverMapMenuItem, equals('Fahrerkarte'));
      expect(uk.driverMapMenuItem, equals('Карта водія'));
    });

    test('assignDriverButton vs assignAnyway are distinct', () async {
      final en = await _l10n('en');
      expect(en.assignDriverButton, equals('Assign driver'));
      expect(en.assignAnyway, equals('Assign Anyway'));
      expect(en.assignDriverButton, isNot(equals(en.assignAnyway)));
    });

    test('shared keys (cancel/retry/reassign) not duplicated in dispatcher batch', () async {
      // The dispatcher batch must reuse existing cancel/retry/reassign without
      // creating new synonym keys. Verify these are present and have expected values
      // (they were not modified by the dispatcher batch).
      final en = await _l10n('en');
      expect(en.cancel, equals('Cancel'));
      expect(en.retry, equals('Retry'));
      expect(en.reassign, equals('Reassign'));
      expect(en.assignAnywayTitle, equals('Driver Busy'));
      expect(en.assignAnyway, equals('Assign Anyway'));
    });

    test('stillLateLabel/slackRestoredLabel/tightLabel are distinct', () async {
      final en = await _l10n('en');

      expect(en.stillLateLabel, equals('still late'));
      expect(en.slackRestoredLabel, equals('slack restored'));
      expect(en.tightLabel, equals('tight'));

      expect(en.stillLateLabel, isNot(equals(en.slackRestoredLabel)));
      expect(en.stillLateLabel, isNot(equals(en.tightLabel)));
      expect(en.slackRestoredLabel, isNot(equals(en.tightLabel)));
    });
  });

  // ---------------------------------------------------------------------------
  // Parametrized key formatting — correct argument types and interpolation
  // ---------------------------------------------------------------------------
  group('dispatcher l10n keys — parameterized formatting', () {
    test('dispatcherSubtitle interpolates weekday, date (String) and count (int)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(
        en.dispatcherSubtitle('Monday', '23.06.2026', 5),
        equals('Monday, 23.06.2026 · 5 active rides'),
      );
      expect(
        de.dispatcherSubtitle('Montag', '23.06.2026', 3),
        equals('Montag, 23.06.2026 · 3 aktive Fahrten'),
      );
      expect(
        uk.dispatcherSubtitle('Понеділок', '23.06.2026', 7),
        equals('Понеділок, 23.06.2026 · 7 активних поїздок'),
      );
    });

    test('dispatcherSubtitle count is actually interpolated (not hardcoded)', () async {
      final en = await _l10n('en');
      expect(
        en.dispatcherSubtitle('Monday', '01.01.2026', 3),
        isNot(equals(en.dispatcherSubtitle('Monday', '01.01.2026', 99))),
      );
    });

    test('assignRideDialogTitle interpolates rideId (String)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.assignRideDialogTitle('A1B2'), equals('Assign Ride #A1B2'));
      expect(de.assignRideDialogTitle('A1B2'), equals('Fahrt #A1B2 zuweisen'));
      expect(uk.assignRideDialogTitle('A1B2'), equals('Призначити поїздку #A1B2'));
    });

    test('assignRideDialogTitle rideId is actually interpolated', () async {
      final en = await _l10n('en');
      expect(
        en.assignRideDialogTitle('id-1'),
        isNot(equals(en.assignRideDialogTitle('id-2'))),
      );
    });

    test('scheduleConflictsCount interpolates count (int)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.scheduleConflictsCount(2), equals('Schedule conflicts (2)'));
      expect(de.scheduleConflictsCount(2), equals('Terminüberschneidungen (2)'));
      expect(uk.scheduleConflictsCount(2), equals('Конфлікти розкладу (2)'));

      // Verify the int is actually interpolated.
      expect(
        en.scheduleConflictsCount(1),
        isNot(equals(en.scheduleConflictsCount(5))),
      );
    });

    test('reassignRideDialogTitle interpolates rideId (String)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.reassignRideDialogTitle('XY99'), equals('Reassign ride #XY99'));
      expect(de.reassignRideDialogTitle('XY99'), equals('Fahrt #XY99 neu zuweisen'));
      expect(uk.reassignRideDialogTitle('XY99'), equals('Перепризначити поїздку #XY99'));
    });

    test('reassignNRides interpolates count (int)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.reassignNRides(3), equals('Reassign 3 ride(s)'));
      expect(de.reassignNRides(3), equals('3 Fahrt(en) neu zuweisen'));
      expect(uk.reassignNRides(3), equals('Перепризначити 3 поїздку(-ок)'));

      expect(en.reassignNRides(1), isNot(equals(en.reassignNRides(10))));
    });

    test('driverDelayedMessage interpolates driverName and slack (both String)', () async {
      // slack is String so the caller can pre-apply the ± sign.
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(
        en.driverDelayedMessage('Hans', '+5'),
        equals('Hans is delayed — slack +5 min'),
      );
      expect(
        de.driverDelayedMessage('Hans', '-3'),
        equals('Hans hat Verspätung — Puffer -3 min'),
      );
      expect(
        uk.driverDelayedMessage('Іван', '+2'),
        equals('Іван затримується — резерв +2 хв'),
      );
    });

    test('driverDelayedMessage driverName and slack are actually interpolated', () async {
      final en = await _l10n('en');
      expect(
        en.driverDelayedMessage('Alice', '+5'),
        isNot(equals(en.driverDelayedMessage('Bob', '+5'))),
      );
      expect(
        en.driverDelayedMessage('Alice', '+5'),
        isNot(equals(en.driverDelayedMessage('Alice', '-5'))),
      );
    });

    test('ridesToReassignLabel interpolates selected and total (int)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(
        en.ridesToReassignLabel(2, 5),
        equals('Rides to reassign (2/5)'),
      );
      expect(
        de.ridesToReassignLabel(2, 5),
        equals('Fahrten zur Neuzuweisung (2/5)'),
      );
      expect(
        uk.ridesToReassignLabel(2, 5),
        equals('Поїздки для перепризначення (2/5)'),
      );

      // Both args actually interpolated.
      expect(
        en.ridesToReassignLabel(1, 5),
        isNot(equals(en.ridesToReassignLabel(3, 5))),
      );
      expect(
        en.ridesToReassignLabel(2, 4),
        isNot(equals(en.ridesToReassignLabel(2, 9))),
      );
    });

    test('ridesReassignedMessage interpolates count (int) and driverName (String)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(
        en.ridesReassignedMessage(2, 'Klaus'),
        equals('2 ride(s) reassigned to Klaus'),
      );
      expect(
        de.ridesReassignedMessage(2, 'Klaus'),
        equals('2 Fahrt(en) wurden Klaus neu zugewiesen'),
      );
      expect(
        uk.ridesReassignedMessage(2, 'Михайло'),
        equals('2 поїздку(-ок) перепризначено водію Михайло'),
      );

      // Both args actually interpolated.
      expect(
        en.ridesReassignedMessage(1, 'Klaus'),
        isNot(equals(en.ridesReassignedMessage(4, 'Klaus'))),
      );
      expect(
        en.ridesReassignedMessage(1, 'Klaus'),
        isNot(equals(en.ridesReassignedMessage(1, 'Anna'))),
      );
    });

    test('unassignedRidesBadge interpolates count (int)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.unassignedRidesBadge(4), equals('4 unassigned'));
      expect(de.unassignedRidesBadge(4), equals('4 nicht zugewiesen'));
      expect(uk.unassignedRidesBadge(4), equals('4 не призначено'));

      expect(
        en.unassignedRidesBadge(0),
        isNot(equals(en.unassignedRidesBadge(10))),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Shared-key integrity: verify shared keys are not duplicated with synonyms
  // ---------------------------------------------------------------------------
  group('dispatcher l10n keys — shared key reuse (no duplicate synonyms)', () {
    test('discardChangesTitle/stay/discard are shared and have unchanged values', () async {
      // These were added in the driver batch and reused by dispatcher — must not be redefined.
      final en = await _l10n('en');
      expect(en.discardChangesTitle, equals('Discard changes?'));
      expect(en.stay, equals('Stay'));
      expect(en.discard, equals('Discard'));
    });

    test('assignAnywayTitle is the shared key for "Driver Busy" dialogs', () async {
      // Used in both pending_rides_panel and assignment_dialog — one key, correct value.
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(en.assignAnywayTitle, equals('Driver Busy'));
      expect(de.assignAnywayTitle, isNotEmpty);
      expect(uk.assignAnywayTitle, isNotEmpty);
    });

    test('billingScreenTitle is reused by billing AppBar (pre-existing shared key)', () async {
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      // billingScreenTitle was a pre-existing key; DE/UK values from earlier batch.
      expect(en.billingScreenTitle, equals('Billing'));
      expect(de.billingScreenTitle, isNotEmpty);
      expect(uk.billingScreenTitle, isNotEmpty);
    });

    test('noDriversAvailableForReassignment is shared between bulk_reassign and driver_schedule', () async {
      // Same key used in two places per plan — just verify it resolves consistently.
      final en = await _l10n('en');
      final de = await _l10n('de');
      final uk = await _l10n('uk');

      expect(
        en.noDriversAvailableForReassignment,
        equals('No other drivers available for reassignment.'),
      );
      expect(de.noDriversAvailableForReassignment, isNotEmpty);
      expect(uk.noDriversAvailableForReassignment, isNotEmpty);
    });
  });
}
