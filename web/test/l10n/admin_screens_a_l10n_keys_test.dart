// Tests that all ~140 new admin/backend-screen l10n keys (added in the
// l10n-admin-screens refactor, sub-task A) resolve to non-empty strings in all
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
  // ─────────────────────────────────────────────────────────────────────────────
  // EN parity — all new keys present and non-empty
  // ─────────────────────────────────────────────────────────────────────────────
  group('admin-screens-A l10n keys — EN parity', () {
    test('ride_templates_screen keys', () async {
      final en = await _l10n('en');

      expect(en.savedTemplatesTitle, isNotEmpty);
      expect(en.createTemplateDialogTitle, isNotEmpty);
      expect(en.templateNameLabel, isNotEmpty);
      expect(en.fromAddressLabel, isNotEmpty);
      expect(en.toAddressLabel, isNotEmpty);
      expect(en.templatePickupTimeLabel, isNotEmpty);
      expect(en.recurrenceLabel, isNotEmpty);
      expect(en.recurrenceDaily, isNotEmpty);
      expect(en.recurrenceWeekdays, isNotEmpty);
      expect(en.recurrenceWeeklyMonday, isNotEmpty);
      expect(en.recurrenceWeeklyTuesday, isNotEmpty);
      expect(en.recurrenceWeeklyWednesday, isNotEmpty);
      expect(en.recurrenceWeeklyThursday, isNotEmpty);
      expect(en.recurrenceWeeklyFriday, isNotEmpty);
      expect(en.recurrenceSaturdayLabel, isNotEmpty);
      expect(en.recurrenceSundayLabel, isNotEmpty);
      expect(en.priceOptionalLabel, isNotEmpty);
      expect(en.generateRidesMenuLabel, isNotEmpty);
      expect(en.deactivateTemplateMenuLabel, isNotEmpty);
      expect(en.noTemplatesYet, isNotEmpty);
      expect(en.noTemplatesSubtitle, isNotEmpty);
      expect(en.addTemplateButton, isNotEmpty);
      expect(en.ridesGeneratedSuccess, isNotEmpty);
      expect(en.failedToGenerateRides('err'), isNotEmpty);
      expect(en.failedToDeactivateTemplate('err'), isNotEmpty);
      expect(en.templateBadgeActive, isNotEmpty);
      expect(en.templateBadgePaused, isNotEmpty);
    });

    test('geofence_screen keys', () async {
      final en = await _l10n('en');

      expect(en.geofenceScreenTitle, isNotEmpty);
      expect(en.zonesTabLabel, isNotEmpty);
      expect(en.recentAlertsTabLabel, isNotEmpty);
      expect(en.createGeofenceDialogTitle, isNotEmpty);
      expect(en.zoneNameLabel, isNotEmpty);
      expect(en.geofenceTypeLabel, isNotEmpty);
      expect(en.geofenceTypeServiceArea, isNotEmpty);
      expect(en.geofenceTypeClientPickup, isNotEmpty);
      expect(en.geofenceTypeCustomZone, isNotEmpty);
      expect(en.latitudeLabel, isNotEmpty);
      expect(en.longitudeLabel, isNotEmpty);
      expect(en.radiusLabel, isNotEmpty);
      expect(en.noGeofenceZonesYet, isNotEmpty);
      expect(en.createZonesToMonitorSubtitle, isNotEmpty);
      expect(en.geofenceDeletedSuccess, isNotEmpty);
      expect(en.geofenceCreatedSuccess, isNotEmpty);
      expect(en.fillRequiredFieldsError, isNotEmpty);
      expect(en.deleteZoneConfirmTitle, isNotEmpty);
      expect(en.deleteZoneConfirmMsg('Munich Airport Zone'), isNotEmpty);
      expect(en.alertFilterLabel, isNotEmpty);
      expect(en.alertFilterEntry, isNotEmpty);
      expect(en.alertFilterExit, isNotEmpty);
      expect(en.failedToLoadGeofences('404'), isNotEmpty);
      expect(en.failedToLoadAlerts('500'), isNotEmpty);
      expect(en.failedToToggleGeofence('403'), isNotEmpty);
      expect(en.failedToCreateGeofence('400'), isNotEmpty);
    });

    test('notification_center_screen keys', () async {
      final en = await _l10n('en');

      expect(en.notifTabNotifications, isNotEmpty);
      expect(en.notifTabSettings, isNotEmpty);
      expect(en.notifFilterAll, isNotEmpty);
      expect(en.notifFilterRides, isNotEmpty);
      expect(en.notifFilterChat, isNotEmpty);
      expect(en.notifFilterGeofence, isNotEmpty);
      expect(en.notifFilterPools, isNotEmpty);
      expect(en.notifFilterCheckpoints, isNotEmpty);
      expect(en.notifJustNow, isNotEmpty);
      expect(en.notifMinutesAgo(5), isNotEmpty);
      expect(en.notifHoursAgo(2), isNotEmpty);
      expect(en.notifDaysAgo(3), isNotEmpty);
      expect(en.notifPrefSectionPush, isNotEmpty);
      expect(en.notifPrefSectionAdditional, isNotEmpty);
      expect(en.notifPrefRideUpdatesSubtitle, isNotEmpty);
      expect(en.notifPrefChatMessagesSubtitle, isNotEmpty);
      expect(en.notifPrefDriverApproachingLabel, isNotEmpty);
      expect(en.notifPrefDriverApproachingSubtitle, isNotEmpty);
      expect(en.notifPrefGeofenceAlertsLabel, isNotEmpty);
      expect(en.notifPrefGeofenceAlertsSubtitle, isNotEmpty);
      expect(en.notifPrefPoolUpdatesLabel, isNotEmpty);
      expect(en.notifPrefPoolUpdatesSubtitle, isNotEmpty);
      expect(en.notifPrefEmailLabel, isNotEmpty);
      expect(en.notifPrefEmailSubtitle, isNotEmpty);
      expect(en.notifPrefSmsLabel, isNotEmpty);
      expect(en.notifPrefSmsSubtitle, isNotEmpty);
      expect(en.notifPrefQuietHours, isNotEmpty);
      expect(en.notifPrefQuietHoursFrom, isNotEmpty);
      expect(en.notifPrefQuietHoursTo, isNotEmpty);
      expect(en.notifPrefNotSet, isNotEmpty);
    });

    test('session_management_screen keys', () async {
      final en = await _l10n('en');

      expect(en.activeSessions, isNotEmpty);
      expect(en.noActiveSessions, isNotEmpty);
      expect(en.sessionCurrentLabel, isNotEmpty);
      expect(en.sessionIpLabel('192.168.1.1'), isNotEmpty);
      expect(en.sessionCreatedLabel('01.01.2024'), isNotEmpty);
      expect(en.sessionLastActiveLabel('01.01.2024'), isNotEmpty);
      expect(en.revokeSessionAction, isNotEmpty);
      expect(en.revokeSessionDialogTitle, isNotEmpty);
      expect(en.revokeSessionDialogContent, isNotEmpty);
      expect(en.revokeSessionButton, isNotEmpty);
      expect(en.revokeAllOtherSessionsDialogTitle, isNotEmpty);
      expect(en.revokeAllOtherSessionsDialogContent, isNotEmpty);
      expect(en.revokeAllButton, isNotEmpty);
      expect(en.sessionRevoked, isNotEmpty);
      expect(en.allOtherSessionsRevoked, isNotEmpty);
    });

    test('admin_users_screen keys', () async {
      final en = await _l10n('en');

      expect(en.userManagementTitle, isNotEmpty);
      expect(en.createUserDialogTitle, isNotEmpty);
      expect(en.searchUsersHint, isNotEmpty);
      expect(en.changeRoleMenuHeader, isNotEmpty);
      expect(en.changeStatusMenuHeader, isNotEmpty);
      expect(en.activateUserAction, isNotEmpty);
      expect(en.suspendUserAction, isNotEmpty);
      expect(en.deactivateUserAction, isNotEmpty);
      expect(en.noUsersFound, isNotEmpty);
      expect(en.totalUsersLabel, isNotEmpty);
      expect(en.driversStatLabel, isNotEmpty);
      expect(en.clientsStatLabel, isNotEmpty);
      expect(en.staffStatLabel, isNotEmpty);
      expect(en.roleChangedSuccess('Admin'), isNotEmpty);
      expect(en.statusChangedSuccess('Active'), isNotEmpty);
      expect(en.failedToChangeRole('err'), isNotEmpty);
      expect(en.failedToChangeStatus('err'), isNotEmpty);
      expect(en.failedToCreateUser('err'), isNotEmpty);
    });

    test('blacklist_screen keys', () async {
      final en = await _l10n('en');

      expect(en.blacklistTitle, isNotEmpty);
      expect(en.addBlacklistEntryDialogTitle, isNotEmpty);
      expect(en.clientIdLabel, isNotEmpty);
      expect(en.driverIdLabel, isNotEmpty);
      expect(en.reasonOptionalLabel, isNotEmpty);
      expect(en.clientDriverIdRequired, isNotEmpty);
      expect(en.removeBlacklistEntryDialogTitle, isNotEmpty);
      expect(en.removeBlacklistEntryContent, isNotEmpty);
      expect(en.removeBlacklistEntryButton, isNotEmpty);
      expect(en.noBlacklistEntries, isNotEmpty);
      expect(en.addButton, isNotEmpty);
    });

    test('superadmin_companies_screen keys', () async {
      final en = await _l10n('en');

      expect(en.tenantsWithCount(5), isNotEmpty);
      expect(en.tenantsTitle, isNotEmpty);
      expect(en.onboardButton, isNotEmpty);
      expect(en.noTenantsFound, isNotEmpty);
      expect(en.colHeaderCompany, isNotEmpty);
      expect(en.colHeaderStatus, isNotEmpty);
      expect(en.colHeaderPlan, isNotEmpty);
      expect(en.colHeaderRidesPerMonth, isNotEmpty);
      expect(en.colHeaderDrivers, isNotEmpty);
      expect(en.setActiveAction, isNotEmpty);
      expect(en.setTrialAction, isNotEmpty);
      expect(en.suspendAction, isNotEmpty);
      expect(en.deactivateCompanyDialogTitle, isNotEmpty);
      expect(en.deactivateCompanyDialogContent('Acme'), isNotEmpty);
      expect(en.onboardCompanyDialogTitle, isNotEmpty);
      expect(en.editCompanyDialogTitle, isNotEmpty);
      expect(en.subscriptionPlanLabel, isNotEmpty);
    });

    test('emergency_reassignment_screen keys', () async {
      final en = await _l10n('en');

      expect(en.emergencyReassignmentTitle, isNotEmpty);
      expect(en.emergencyReassignmentDialogTitle, isNotEmpty);
      expect(en.rideIdLabel, isNotEmpty);
      expect(en.emergencyReasonLabel, isNotEmpty);
      expect(en.availableDriversLabel, isNotEmpty);
      expect(en.newDriverIdLabel, isNotEmpty);
      expect(en.newDriverIdHelper, isNotEmpty);
      expect(en.reassignButton, isNotEmpty);
      expect(en.rideIdRequired, isNotEmpty);
      expect(en.emergencyReassignmentCreated, isNotEmpty);
      expect(en.noEmergencyReassignments, isNotEmpty);
      expect(en.emergencyReasonDriverIllness, isNotEmpty);
      expect(en.emergencyReasonVehicleBreakdown, isNotEmpty);
      expect(en.emergencyReasonDriverNoShow, isNotEmpty);
      expect(en.emergencyReasonAccident, isNotEmpty);
      expect(en.emergencyReasonPersonalEmergency, isNotEmpty);
      expect(en.emergencyReasonOther, isNotEmpty);
      expect(en.emergencyRideLabel('abc123'), isNotEmpty);
      expect(en.emergencyOriginalDriverLabel('abc123'), isNotEmpty);
      expect(en.emergencyNewDriverLabel('abc123'), isNotEmpty);
    });

    test('ride_pool_screen keys', () async {
      final en = await _l10n('en');

      expect(en.ridePoolsTitle, isNotEmpty);
      expect(en.createRidePoolDialogTitle, isNotEmpty);
      expect(en.poolNameOptionalLabel, isNotEmpty);
      expect(en.poolNameHint, isNotEmpty);
      expect(en.routeDirectionOptionalLabel, isNotEmpty);
      expect(en.routeDirectionHint, isNotEmpty);
      expect(en.maxPassengersLabel, isNotEmpty);
      expect(en.ridePoolCreated, isNotEmpty);
      expect(en.noRidePools, isNotEmpty);
      expect(en.createPoolToCombineRides, isNotEmpty);
      expect(en.errorLoadingPoolDetails('oops'), isNotEmpty);
      expect(en.poolDetailStatusLabel, isNotEmpty);
      expect(en.poolDetailPassengersLabel, isNotEmpty);
      expect(en.poolDetailRouteLabel, isNotEmpty);
      expect(en.poolDetailDriverLabel, isNotEmpty);
      expect(en.poolMembersLabel, isNotEmpty);
      expect(en.noRidesInPool, isNotEmpty);
    });

    test('company_settings_screen keys', () async {
      final en = await _l10n('en');

      expect(en.companySettingsTitle, isNotEmpty);
      expect(en.navItemCompany, isNotEmpty);
      expect(en.navItemUsersRoles, isNotEmpty);
      expect(en.navItemCompliance, isNotEmpty);
      expect(en.navItemBillingDatev, isNotEmpty);
      expect(en.navItemGeofences, isNotEmpty);
      expect(en.companyProfileSectionTitle, isNotEmpty);
      expect(en.companyProfileSubtitle, isNotEmpty);
      expect(en.complianceSectionTitle, isNotEmpty);
      expect(en.complianceSubtitle, isNotEmpty);
      expect(en.billingDatevSectionTitle, isNotEmpty);
      expect(en.billingDatevSubtitle, isNotEmpty);
      expect(en.tariffSettingsSectionTitle, isNotEmpty);
      expect(en.datevIntegrationSectionTitle, isNotEmpty);
      expect(en.datevIntegrationSubtitle, isNotEmpty);
      expect(en.legalNameLabel, isNotEmpty);
      expect(en.vatIdLabel, isNotEmpty);
      expect(en.defaultCurrencyLabel, isNotEmpty);
      expect(en.timezoneLabel, isNotEmpty);
      expect(en.commissionRateLabel, isNotEmpty);
      expect(en.cancellationFeeSettingsLabel, isNotEmpty);
      expect(en.noShowFeeLabel, isNotEmpty);
      expect(en.basePriceLabel, isNotEmpty);
      expect(en.pricePerKmLabel, isNotEmpty);
      expect(en.airportSurchargeLabel, isNotEmpty);
      expect(en.nightSurchargeLabel, isNotEmpty);
      expect(en.workStartLabel, isNotEmpty);
      expect(en.workEndLabel, isNotEmpty);
      expect(en.settingsSavedSuccess, isNotEmpty);
      expect(en.failedToSaveSettings('err'), isNotEmpty);
      expect(en.gdprExportTitle, isNotEmpty);
      expect(en.gdprExportSubtitle, isNotEmpty);
      expect(en.auditLogTitle, isNotEmpty);
      expect(en.auditLogSubtitle, isNotEmpty);
      expect(en.activeSessionsCardTitle, isNotEmpty);
      expect(en.activeSessionsCardSubtitle, isNotEmpty);
      expect(en.blacklistCardTitle, isNotEmpty);
      expect(en.blacklistCardSubtitle, isNotEmpty);
      expect(en.comingSoonLabel('Users & Roles'), isNotEmpty);
      expect(en.settingsCompanyProfile, isNotEmpty);
      expect(en.generalSettingsSectionTitle, isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // DE parity — all new keys present and non-empty
  // ─────────────────────────────────────────────────────────────────────────────
  group('admin-screens-A l10n keys — DE parity', () {
    test('all new keys present and non-empty in German', () async {
      final de = await _l10n('de');

      // ride_templates_screen
      expect(de.savedTemplatesTitle, isNotEmpty);
      expect(de.createTemplateDialogTitle, isNotEmpty);
      expect(de.templateNameLabel, isNotEmpty);
      expect(de.fromAddressLabel, isNotEmpty);
      expect(de.toAddressLabel, isNotEmpty);
      expect(de.templatePickupTimeLabel, isNotEmpty);
      expect(de.recurrenceLabel, isNotEmpty);
      expect(de.recurrenceDaily, isNotEmpty);
      expect(de.recurrenceWeekdays, isNotEmpty);
      expect(de.recurrenceWeeklyMonday, isNotEmpty);
      expect(de.recurrenceWeeklyFriday, isNotEmpty);
      expect(de.recurrenceSaturdayLabel, isNotEmpty);
      expect(de.recurrenceSundayLabel, isNotEmpty);
      expect(de.priceOptionalLabel, isNotEmpty);
      expect(de.generateRidesMenuLabel, isNotEmpty);
      expect(de.noTemplatesYet, isNotEmpty);
      expect(de.addTemplateButton, isNotEmpty);
      expect(de.templateBadgeActive, isNotEmpty);
      expect(de.templateBadgePaused, isNotEmpty);

      // geofence_screen
      expect(de.geofenceScreenTitle, isNotEmpty);
      expect(de.zonesTabLabel, isNotEmpty);
      expect(de.createGeofenceDialogTitle, isNotEmpty);
      expect(de.zoneNameLabel, isNotEmpty);
      expect(de.geofenceTypeLabel, isNotEmpty);
      expect(de.radiusLabel, isNotEmpty);
      expect(de.geofenceDeletedSuccess, isNotEmpty);
      expect(de.geofenceCreatedSuccess, isNotEmpty);
      expect(de.alertFilterEntry, isNotEmpty);
      expect(de.alertFilterExit, isNotEmpty);
      expect(de.failedToLoadGeofences('404'), isNotEmpty);
      expect(de.failedToCreateGeofence('400'), isNotEmpty);

      // notification_center_screen
      expect(de.notifTabNotifications, isNotEmpty);
      expect(de.notifTabSettings, isNotEmpty);
      expect(de.notifFilterAll, isNotEmpty);
      expect(de.notifJustNow, isNotEmpty);
      expect(de.notifMinutesAgo(5), isNotEmpty);
      expect(de.notifHoursAgo(2), isNotEmpty);
      expect(de.notifDaysAgo(3), isNotEmpty);
      expect(de.notifPrefSectionPush, isNotEmpty);

      // session_management_screen
      expect(de.activeSessions, isNotEmpty);
      expect(de.noActiveSessions, isNotEmpty);
      expect(de.revokeSessionDialogTitle, isNotEmpty);
      expect(de.revokeSessionButton, isNotEmpty);
      expect(de.sessionRevoked, isNotEmpty);
      expect(de.allOtherSessionsRevoked, isNotEmpty);

      // admin_users_screen
      expect(de.userManagementTitle, isNotEmpty);
      expect(de.searchUsersHint, isNotEmpty);
      expect(de.noUsersFound, isNotEmpty);
      expect(de.roleChangedSuccess('Admin'), isNotEmpty);
      expect(de.failedToCreateUser('err'), isNotEmpty);

      // blacklist_screen
      expect(de.blacklistTitle, isNotEmpty);
      expect(de.clientIdLabel, isNotEmpty);
      expect(de.noBlacklistEntries, isNotEmpty);

      // superadmin_companies_screen
      expect(de.tenantsWithCount(5), isNotEmpty);
      expect(de.tenantsTitle, isNotEmpty);
      expect(de.noTenantsFound, isNotEmpty);
      expect(de.deactivateCompanyDialogContent('Acme'), isNotEmpty);

      // emergency_reassignment_screen
      expect(de.emergencyReassignmentTitle, isNotEmpty);
      expect(de.emergencyReasonDriverIllness, isNotEmpty);
      expect(de.emergencyRideLabel('abc'), isNotEmpty);

      // ride_pool_screen
      expect(de.ridePoolsTitle, isNotEmpty);
      expect(de.createRidePoolDialogTitle, isNotEmpty);
      expect(de.noRidePools, isNotEmpty);
      expect(de.errorLoadingPoolDetails('oops'), isNotEmpty);

      // company_settings_screen
      expect(de.companySettingsTitle, isNotEmpty);
      expect(de.navItemBillingDatev, isNotEmpty);
      expect(de.settingsSavedSuccess, isNotEmpty);
      expect(de.failedToSaveSettings('err'), isNotEmpty);
      expect(de.comingSoonLabel('X'), isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // UK parity — all new keys present and non-empty
  // ─────────────────────────────────────────────────────────────────────────────
  group('admin-screens-A l10n keys — UK parity', () {
    test('all new keys present and non-empty in Ukrainian', () async {
      final uk = await _l10n('uk');

      // ride_templates_screen
      expect(uk.savedTemplatesTitle, isNotEmpty);
      expect(uk.createTemplateDialogTitle, isNotEmpty);
      expect(uk.templatePickupTimeLabel, isNotEmpty);
      expect(uk.priceOptionalLabel, isNotEmpty);
      expect(uk.generateRidesMenuLabel, isNotEmpty);
      expect(uk.templateBadgeActive, isNotEmpty);
      expect(uk.templateBadgePaused, isNotEmpty);

      // geofence_screen
      expect(uk.geofenceScreenTitle, isNotEmpty);
      expect(uk.geofenceDeletedSuccess, isNotEmpty);
      expect(uk.failedToLoadGeofences('err'), isNotEmpty);
      expect(uk.failedToCreateGeofence('err'), isNotEmpty);

      // notification_center_screen
      expect(uk.notifTabNotifications, isNotEmpty);
      expect(uk.notifJustNow, isNotEmpty);
      expect(uk.notifMinutesAgo(5), isNotEmpty);
      expect(uk.notifHoursAgo(2), isNotEmpty);
      expect(uk.notifDaysAgo(3), isNotEmpty);

      // session_management_screen
      expect(uk.activeSessions, isNotEmpty);
      expect(uk.revokeSessionButton, isNotEmpty);
      expect(uk.sessionRevoked, isNotEmpty);

      // admin_users_screen
      expect(uk.userManagementTitle, isNotEmpty);
      expect(uk.noUsersFound, isNotEmpty);
      expect(uk.roleChangedSuccess('Admin'), isNotEmpty);

      // blacklist_screen
      expect(uk.blacklistTitle, isNotEmpty);
      expect(uk.noBlacklistEntries, isNotEmpty);

      // superadmin_companies_screen
      expect(uk.tenantsWithCount(5), isNotEmpty);
      expect(uk.noTenantsFound, isNotEmpty);

      // emergency_reassignment_screen
      expect(uk.emergencyReassignmentTitle, isNotEmpty);
      expect(uk.emergencyReasonDriverIllness, isNotEmpty);
      expect(uk.emergencyRideLabel('abc'), isNotEmpty);

      // ride_pool_screen
      expect(uk.ridePoolsTitle, isNotEmpty);
      expect(uk.noRidePools, isNotEmpty);
      expect(uk.errorLoadingPoolDetails('oops'), isNotEmpty);

      // company_settings_screen
      expect(uk.companySettingsTitle, isNotEmpty);
      expect(uk.settingsSavedSuccess, isNotEmpty);
      expect(uk.failedToSaveSettings('err'), isNotEmpty);
      expect(uk.comingSoonLabel('X'), isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Semantic spot-checks — EN values match expected English strings
  // ─────────────────────────────────────────────────────────────────────────────
  group('admin-screens-A l10n keys — EN semantic checks', () {
    test('parameterised keys produce correct output', () async {
      final en = await _l10n('en');

      expect(en.notifMinutesAgo(5), contains('5'));
      expect(en.notifHoursAgo(2), contains('2'));
      expect(en.notifDaysAgo(3), contains('3'));
      expect(en.sessionIpLabel('10.0.0.1'), contains('10.0.0.1'));
      expect(en.sessionCreatedLabel('01.06.2024'), contains('01.06.2024'));
      expect(en.roleChangedSuccess('Driver'), contains('Driver'));
      expect(en.statusChangedSuccess('Active'), contains('Active'));
      expect(en.failedToChangeRole('timeout'), contains('timeout'));
      expect(en.tenantsWithCount(7), contains('7'));
      expect(
        en.deactivateCompanyDialogContent('Munich Taxi'),
        contains('Munich Taxi'),
      );
      expect(en.emergencyRideLabel('ride-001'), contains('ride-001'));
      expect(en.emergencyOriginalDriverLabel('drv-001'), contains('drv-001'));
      expect(en.emergencyNewDriverLabel('drv-002'), contains('drv-002'));
      expect(
        en.errorLoadingPoolDetails('connection refused'),
        contains('connection refused'),
      );
      expect(
        en.failedToSaveSettings('network error'),
        contains('network error'),
      );
      expect(en.comingSoonLabel('Geofences'), contains('Geofences'));
      expect(en.failedToLoadGeofences('500'), contains('500'));
      expect(en.failedToCreateGeofence('422'), contains('422'));
      expect(en.failedToGenerateRides('timeout'), contains('timeout'));
      expect(en.failedToDeactivateTemplate('forbidden'), contains('forbidden'));
      expect(en.failedToCreateUser('conflict'), contains('conflict'));
    });

    test('static keys have correct English text', () async {
      final en = await _l10n('en');

      expect(en.companySettingsTitle, equals('Company Settings'));
      expect(en.ridePoolsTitle, equals('Ride Pools'));
      expect(en.blacklistTitle, equals('Blacklist'));
      expect(en.userManagementTitle, equals('User Management'));
      expect(en.emergencyReassignmentTitle, equals('Emergency Reassignments'));
      expect(en.settingsSavedSuccess, equals('Settings saved successfully'));
      expect(en.templateBadgeActive, equals('Active'));
      expect(en.templateBadgePaused, equals('Paused'));
      expect(en.priceOptionalLabel, equals('Price (optional)'));
      expect(en.noRidePools, equals('No ride pools'));
      expect(en.noBlacklistEntries, equals('No blacklist entries'));
      expect(en.notifJustNow, equals('Just now'));
      expect(en.geofenceDeletedSuccess, equals('Geofence deleted'));
      expect(en.geofenceCreatedSuccess, equals('Geofence created'));
      expect(en.sessionRevoked, equals('Session revoked'));
      expect(en.allOtherSessionsRevoked, equals('All other sessions revoked'));
    });
  });
}
