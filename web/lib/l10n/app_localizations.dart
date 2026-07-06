import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Dispax'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidCredentials;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @myRides.
  ///
  /// In en, this message translates to:
  /// **'My Rides'**
  String get myRides;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @flights.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get flights;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @pendingRides.
  ///
  /// In en, this message translates to:
  /// **'Pending Rides'**
  String get pendingRides;

  /// No description provided for @ridesAwaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} ride(s) awaiting assignment'**
  String ridesAwaiting(int count);

  /// No description provided for @driverSchedules.
  ///
  /// In en, this message translates to:
  /// **'Driver Schedules'**
  String get driverSchedules;

  /// No description provided for @noDriversScheduled.
  ///
  /// In en, this message translates to:
  /// **'No drivers scheduled'**
  String get noDriversScheduled;

  /// No description provided for @selectDriverToViewSchedule.
  ///
  /// In en, this message translates to:
  /// **'Select a driver to view their schedule'**
  String get selectDriverToViewSchedule;

  /// No description provided for @noScheduleForDriver.
  ///
  /// In en, this message translates to:
  /// **'No schedule entries for this driver'**
  String get noScheduleForDriver;

  /// No description provided for @noPendingRides.
  ///
  /// In en, this message translates to:
  /// **'No pending rides'**
  String get noPendingRides;

  /// Info snackbar shown when a dispatcher tries to assign a ride that another dispatcher (or auto-assignment) already took; the pending list is reloaded instead of showing an error.
  ///
  /// In en, this message translates to:
  /// **'This ride was already assigned. The list has been refreshed.'**
  String get rideAlreadyAssignedInfo;

  /// No description provided for @allRidesAssigned.
  ///
  /// In en, this message translates to:
  /// **'All rides have been assigned'**
  String get allRidesAssigned;

  /// No description provided for @selectDriver.
  ///
  /// In en, this message translates to:
  /// **'Select Driver'**
  String get selectDriver;

  /// No description provided for @reassignDriver.
  ///
  /// In en, this message translates to:
  /// **'Reassign Driver'**
  String get reassignDriver;

  /// No description provided for @noDriversFound.
  ///
  /// In en, this message translates to:
  /// **'No drivers found'**
  String get noDriversFound;

  /// No description provided for @reassignRide.
  ///
  /// In en, this message translates to:
  /// **'Reassign Ride'**
  String get reassignRide;

  /// No description provided for @confirmReassignment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Reassignment'**
  String get confirmReassignment;

  /// No description provided for @reassign.
  ///
  /// In en, this message translates to:
  /// **'Reassign'**
  String get reassign;

  /// No description provided for @assign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// No description provided for @driverDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Dashboard'**
  String get driverDashboardTitle;

  /// No description provided for @secretaryDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Secretary Dashboard'**
  String get secretaryDashboardTitle;

  /// No description provided for @dispatcherDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dispatcher Dashboard'**
  String get dispatcherDashboardTitle;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboardTitle;

  /// No description provided for @platformAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Admin'**
  String get platformAdminTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @searchClientAddress.
  ///
  /// In en, this message translates to:
  /// **'Search client, address...'**
  String get searchClientAddress;

  /// No description provided for @searchDriverName.
  ///
  /// In en, this message translates to:
  /// **'Search driver name...'**
  String get searchDriverName;

  /// No description provided for @airport.
  ///
  /// In en, this message translates to:
  /// **'Airport'**
  String get airport;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderate;

  /// No description provided for @busy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get busy;

  /// No description provided for @sortTimeEarliest.
  ///
  /// In en, this message translates to:
  /// **'Time (earliest first)'**
  String get sortTimeEarliest;

  /// No description provided for @sortTimeLatest.
  ///
  /// In en, this message translates to:
  /// **'Time (latest first)'**
  String get sortTimeLatest;

  /// No description provided for @sortClientName.
  ///
  /// In en, this message translates to:
  /// **'Client name'**
  String get sortClientName;

  /// No description provided for @nRidesAssigned.
  ///
  /// In en, this message translates to:
  /// **'{count} ride(s) assigned'**
  String nRidesAssigned(int count);

  /// No description provided for @timeConflicts.
  ///
  /// In en, this message translates to:
  /// **'{count} time conflict(s)'**
  String timeConflicts(int count);

  /// No description provided for @dropHereToAssign.
  ///
  /// In en, this message translates to:
  /// **'Drop here to assign'**
  String get dropHereToAssign;

  /// No description provided for @todaysHistory.
  ///
  /// In en, this message translates to:
  /// **'Today\'s History'**
  String get todaysHistory;

  /// No description provided for @thisWeeksHistory.
  ///
  /// In en, this message translates to:
  /// **'This Week\'s History'**
  String get thisWeeksHistory;

  /// No description provided for @thisMonthsHistory.
  ///
  /// In en, this message translates to:
  /// **'This Month\'s History'**
  String get thisMonthsHistory;

  /// No description provided for @allTimeHistory.
  ///
  /// In en, this message translates to:
  /// **'All Time History'**
  String get allTimeHistory;

  /// No description provided for @rideHistory.
  ///
  /// In en, this message translates to:
  /// **'Ride History'**
  String get rideHistory;

  /// No description provided for @myRideHistory.
  ///
  /// In en, this message translates to:
  /// **'My Ride History'**
  String get myRideHistory;

  /// No description provided for @noRideHistory.
  ///
  /// In en, this message translates to:
  /// **'No Ride History'**
  String get noRideHistory;

  /// No description provided for @completedRidesAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Your completed rides will appear here'**
  String get completedRidesAppearHere;

  /// No description provided for @noRidesForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No rides for this period'**
  String get noRidesForPeriod;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @earned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get earned;

  /// No description provided for @spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spent;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @totalRides.
  ///
  /// In en, this message translates to:
  /// **'Total Rides'**
  String get totalRides;

  /// No description provided for @completedRides.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedRides;

  /// No description provided for @cancelledRides.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelledRides;

  /// No description provided for @inProgressRides.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgressRides;

  /// No description provided for @requestedRides.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requestedRides;

  /// No description provided for @assignedRides.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assignedRides;

  /// No description provided for @activeDrivers.
  ///
  /// In en, this message translates to:
  /// **'Active Drivers'**
  String get activeDrivers;

  /// No description provided for @totalClients.
  ///
  /// In en, this message translates to:
  /// **'Total Clients'**
  String get totalClients;

  /// No description provided for @todayRevenue.
  ///
  /// In en, this message translates to:
  /// **'Today Revenue'**
  String get todayRevenue;

  /// No description provided for @monthlyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Monthly Revenue'**
  String get monthlyRevenue;

  /// No description provided for @avgAssignmentTime.
  ///
  /// In en, this message translates to:
  /// **'Avg. Assignment'**
  String get avgAssignmentTime;

  /// No description provided for @cancellationRate.
  ///
  /// In en, this message translates to:
  /// **'Cancellation %'**
  String get cancellationRate;

  /// No description provided for @driverLoad.
  ///
  /// In en, this message translates to:
  /// **'Driver Load'**
  String get driverLoad;

  /// No description provided for @dailyOverview.
  ///
  /// In en, this message translates to:
  /// **'Daily Overview'**
  String get dailyOverview;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @chatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Chat is available only during active rides'**
  String get chatUnavailable;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessages;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSettings;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChanged;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordPolicyRules.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters with an uppercase letter, a lowercase letter, and a digit'**
  String get passwordPolicyRules;

  /// No description provided for @forcePasswordChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get forcePasswordChangeTitle;

  /// No description provided for @forcePasswordChangeMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account uses a temporary password. Please set a new password to continue.'**
  String get forcePasswordChangeMessage;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequired;

  /// No description provided for @updateRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is no longer supported. Please update to the latest version to continue.'**
  String get updateRequiredMessage;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @temporaryPassword.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get temporaryPassword;

  /// No description provided for @temporaryPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'The user will be asked to change it on first login.'**
  String get temporaryPasswordHint;

  /// No description provided for @tempPasswordRules.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters with an uppercase letter, a lowercase letter, and a digit'**
  String get tempPasswordRules;

  /// No description provided for @setNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get setNewPassword;

  /// No description provided for @userCreatedSharePassword.
  ///
  /// In en, this message translates to:
  /// **'User created. Share the temporary password with them.'**
  String get userCreatedSharePassword;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @rideUpdates.
  ///
  /// In en, this message translates to:
  /// **'Ride Updates'**
  String get rideUpdates;

  /// No description provided for @chatMessages.
  ///
  /// In en, this message translates to:
  /// **'Chat Messages'**
  String get chatMessages;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get german;

  /// No description provided for @ukrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get ukrainian;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdated;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get changePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get removePhoto;

  /// No description provided for @photoUploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded successfully'**
  String get photoUploadedSuccessfully;

  /// No description provided for @failedToUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload photo'**
  String get failedToUploadPhoto;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @biometricLogin.
  ///
  /// In en, this message translates to:
  /// **'Biometric Login'**
  String get biometricLogin;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @backendVersion.
  ///
  /// In en, this message translates to:
  /// **'Backend version'**
  String get backendVersion;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @superAdminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Platform Admin'**
  String get superAdminDashboard;

  /// No description provided for @companies.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get companies;

  /// No description provided for @companiesList.
  ///
  /// In en, this message translates to:
  /// **'Companies List'**
  String get companiesList;

  /// No description provided for @platformAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Platform Analytics'**
  String get platformAnalytics;

  /// No description provided for @platformRevenue.
  ///
  /// In en, this message translates to:
  /// **'Platform Revenue'**
  String get platformRevenue;

  /// No description provided for @activeConnections.
  ///
  /// In en, this message translates to:
  /// **'Active Connections'**
  String get activeConnections;

  /// No description provided for @companyStatus.
  ///
  /// In en, this message translates to:
  /// **'Company Status'**
  String get companyStatus;

  /// No description provided for @subscriptionPlan.
  ///
  /// In en, this message translates to:
  /// **'Subscription Plan'**
  String get subscriptionPlan;

  /// No description provided for @billingAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Billing Analytics'**
  String get billingAnalytics;

  /// No description provided for @connectionAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Connection Analytics'**
  String get connectionAnalytics;

  /// No description provided for @superAdminSettings.
  ///
  /// In en, this message translates to:
  /// **'Platform Settings'**
  String get superAdminSettings;

  /// No description provided for @addCompany.
  ///
  /// In en, this message translates to:
  /// **'Add Company'**
  String get addCompany;

  /// No description provided for @editCompany.
  ///
  /// In en, this message translates to:
  /// **'Edit Company'**
  String get editCompany;

  /// No description provided for @deleteCompany.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Company'**
  String get deleteCompany;

  /// No description provided for @deactivateCompanyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to deactivate this company? The company will be marked as Inactive but all data will be preserved.'**
  String get deactivateCompanyConfirm;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get companyName;

  /// No description provided for @companyEmail.
  ///
  /// In en, this message translates to:
  /// **'Company Email'**
  String get companyEmail;

  /// No description provided for @companyPhone.
  ///
  /// In en, this message translates to:
  /// **'Company Phone'**
  String get companyPhone;

  /// No description provided for @companyAddress.
  ///
  /// In en, this message translates to:
  /// **'Company Address'**
  String get companyAddress;

  /// No description provided for @checkpointLanded.
  ///
  /// In en, this message translates to:
  /// **'Landed'**
  String get checkpointLanded;

  /// No description provided for @checkpointArrivalsHall.
  ///
  /// In en, this message translates to:
  /// **'Arrivals Hall'**
  String get checkpointArrivalsHall;

  /// No description provided for @checkpointTerminalExit.
  ///
  /// In en, this message translates to:
  /// **'Terminal Exit'**
  String get checkpointTerminalExit;

  /// Ride-card line showing the passenger's self-reported airport progress.
  ///
  /// In en, this message translates to:
  /// **'Passenger: {checkpoint}'**
  String passengerCheckpointStatus(String checkpoint);

  /// No description provided for @markCheckpointButton.
  ///
  /// In en, this message translates to:
  /// **'I\'m here'**
  String get markCheckpointButton;

  /// No description provided for @airportCheckpointPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'My location in terminal'**
  String get airportCheckpointPanelTitle;

  /// No description provided for @airportEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Airport Entry Time'**
  String get airportEntryTitle;

  /// No description provided for @airportDepartIn.
  ///
  /// In en, this message translates to:
  /// **'Depart in:'**
  String get airportDepartIn;

  /// No description provided for @airportEntryLabel.
  ///
  /// In en, this message translates to:
  /// **'Airport entry:'**
  String get airportEntryLabel;

  /// No description provided for @airportEntryAt.
  ///
  /// In en, this message translates to:
  /// **'Entry at {time}'**
  String airportEntryAt(String time);

  /// No description provided for @airportLandingAt.
  ///
  /// In en, this message translates to:
  /// **'Landing at {time}'**
  String airportLandingAt(String time);

  /// No description provided for @airportLandedAt.
  ///
  /// In en, this message translates to:
  /// **'Landed at {time}'**
  String airportLandedAt(String time);

  /// No description provided for @airportFlightDelay.
  ///
  /// In en, this message translates to:
  /// **'+{minutes} min delay'**
  String airportFlightDelay(int minutes);

  /// No description provided for @airportScheduledVsActual.
  ///
  /// In en, this message translates to:
  /// **'Scheduled {scheduled} → {actual}'**
  String airportScheduledVsActual(String scheduled, String actual);

  /// No description provided for @airportTravelTime.
  ///
  /// In en, this message translates to:
  /// **'Travel time:'**
  String get airportTravelTime;

  /// No description provided for @airportParkingSavings.
  ///
  /// In en, this message translates to:
  /// **'Parking savings: {amount}'**
  String airportParkingSavings(String amount);

  /// No description provided for @airportDepartNow.
  ///
  /// In en, this message translates to:
  /// **'Depart now!'**
  String get airportDepartNow;

  /// No description provided for @airportFlightDelayed.
  ///
  /// In en, this message translates to:
  /// **'Flight delayed. Entry time recalculated.'**
  String get airportFlightDelayed;

  /// No description provided for @airportTimingError.
  ///
  /// In en, this message translates to:
  /// **'Error loading data: {error}'**
  String airportTimingError(String error);

  /// No description provided for @airportLoadingTiming.
  ///
  /// In en, this message translates to:
  /// **'Loading entry time data...'**
  String get airportLoadingTiming;

  /// No description provided for @checkpointNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Client reached {checkpoint}'**
  String checkpointNotifTitle(String checkpoint);

  /// No description provided for @checkpointNotifBody.
  ///
  /// In en, this message translates to:
  /// **'Your client is at {checkpointName}.'**
  String checkpointNotifBody(String checkpointName);

  /// No description provided for @airportExits.
  ///
  /// In en, this message translates to:
  /// **'Airport Exits'**
  String get airportExits;

  /// No description provided for @addAirport.
  ///
  /// In en, this message translates to:
  /// **'Add Airport'**
  String get addAirport;

  /// No description provided for @editAirport.
  ///
  /// In en, this message translates to:
  /// **'Edit Airport'**
  String get editAirport;

  /// No description provided for @deleteAirport.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Airport'**
  String get deleteAirport;

  /// No description provided for @airportCode.
  ///
  /// In en, this message translates to:
  /// **'Airport Code (e.g. MUC)'**
  String get airportCode;

  /// No description provided for @airportName.
  ///
  /// In en, this message translates to:
  /// **'Airport Name'**
  String get airportName;

  /// No description provided for @addZone.
  ///
  /// In en, this message translates to:
  /// **'Add Zone'**
  String get addZone;

  /// No description provided for @editZone.
  ///
  /// In en, this message translates to:
  /// **'Edit Zone'**
  String get editZone;

  /// No description provided for @deleteZone.
  ///
  /// In en, this message translates to:
  /// **'Delete Zone'**
  String get deleteZone;

  /// No description provided for @terminalCode.
  ///
  /// In en, this message translates to:
  /// **'Terminal (T1, T2, …)'**
  String get terminalCode;

  /// No description provided for @checkpointType.
  ///
  /// In en, this message translates to:
  /// **'Checkpoint Type'**
  String get checkpointType;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitude;

  /// No description provided for @radiusMeters.
  ///
  /// In en, this message translates to:
  /// **'Radius (meters)'**
  String get radiusMeters;

  /// No description provided for @landingGeofence.
  ///
  /// In en, this message translates to:
  /// **'Landing Geofence'**
  String get landingGeofence;

  /// No description provided for @pickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get pickOnMap;

  /// No description provided for @scheduleVisibility.
  ///
  /// In en, this message translates to:
  /// **'Schedule Visibility'**
  String get scheduleVisibility;

  /// No description provided for @allowViewOtherSchedules.
  ///
  /// In en, this message translates to:
  /// **'Allow viewing colleagues\' schedules'**
  String get allowViewOtherSchedules;

  /// No description provided for @viewingDriverSchedule.
  ///
  /// In en, this message translates to:
  /// **'Viewing: {driverName}'**
  String viewingDriverSchedule(String driverName);

  /// No description provided for @flightDepartureTime.
  ///
  /// In en, this message translates to:
  /// **'Flight departure time'**
  String get flightDepartureTime;

  /// No description provided for @manualPickupTimeOptional.
  ///
  /// In en, this message translates to:
  /// **'Pickup time (optional — computed if blank)'**
  String get manualPickupTimeOptional;

  /// No description provided for @confirmedPickupTime.
  ///
  /// In en, this message translates to:
  /// **'Confirmed pickup: {time}'**
  String confirmedPickupTime(String time);

  /// No description provided for @pickupTimeComputedAuto.
  ///
  /// In en, this message translates to:
  /// **'Computed automatically based on flight departure'**
  String get pickupTimeComputedAuto;

  /// No description provided for @addressNotFound.
  ///
  /// In en, this message translates to:
  /// **'Address could not be located — double-check the spelling.'**
  String get addressNotFound;

  /// No description provided for @addressOutOfServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Address is outside the service area (about {distanceKm} km from Munich, max {radiusKm} km).'**
  String addressOutOfServiceArea(int distanceKm, int radiusKm);

  /// No description provided for @addressOutOfServiceAreaShort.
  ///
  /// In en, this message translates to:
  /// **'Address is outside the service area (max {radiusKm} km from Munich).'**
  String addressOutOfServiceAreaShort(int radiusKm);

  /// No description provided for @markUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Mark Unavailable'**
  String get markUnavailable;

  /// No description provided for @driverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Driver Unavailable'**
  String get driverUnavailable;

  /// No description provided for @unavailabilityReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get unavailabilityReason;

  /// No description provided for @unavailabilityNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get unavailabilityNote;

  /// No description provided for @unavailabilityFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get unavailabilityFrom;

  /// No description provided for @unavailabilityTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get unavailabilityTo;

  /// No description provided for @unavailabilityReasonLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get unavailabilityReasonLunch;

  /// No description provided for @unavailabilityReasonVacation.
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get unavailabilityReasonVacation;

  /// No description provided for @unavailabilityReasonPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get unavailabilityReasonPersonal;

  /// No description provided for @driverHasScheduleConflict.
  ///
  /// In en, this message translates to:
  /// **'Driver is busy during this time'**
  String get driverHasScheduleConflict;

  /// No description provided for @assignAnywayTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Busy'**
  String get assignAnywayTitle;

  /// No description provided for @assignAnywayMessage.
  ///
  /// In en, this message translates to:
  /// **'This driver has a schedule conflict: {reason}. Assign anyway?'**
  String assignAnywayMessage(String reason);

  /// No description provided for @assignAnyway.
  ///
  /// In en, this message translates to:
  /// **'Assign Anyway'**
  String get assignAnyway;

  /// No description provided for @unavailabilityCreated.
  ///
  /// In en, this message translates to:
  /// **'Unavailability marked successfully'**
  String get unavailabilityCreated;

  /// No description provided for @unavailabilityDeleted.
  ///
  /// In en, this message translates to:
  /// **'Unavailability removed'**
  String get unavailabilityDeleted;

  /// No description provided for @noUnavailability.
  ///
  /// In en, this message translates to:
  /// **'No unavailability windows'**
  String get noUnavailability;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @faceIdUnlock.
  ///
  /// In en, this message translates to:
  /// **'Face ID unlock'**
  String get faceIdUnlock;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @activeSessions.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get activeSessions;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @myEarnings.
  ///
  /// In en, this message translates to:
  /// **'My Earnings'**
  String get myEarnings;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyDataGdpr.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data (GDPR)'**
  String get privacyDataGdpr;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirm;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @failedToChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password'**
  String get failedToChangePassword;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your dispatch account.'**
  String get signInSubtitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @faceId.
  ///
  /// In en, this message translates to:
  /// **'Face ID'**
  String get faceId;

  /// No description provided for @roleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get roleDriver;

  /// No description provided for @roleClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get roleClient;

  /// No description provided for @roleSecretary.
  ///
  /// In en, this message translates to:
  /// **'Secretary'**
  String get roleSecretary;

  /// No description provided for @roleClientSecretary.
  ///
  /// In en, this message translates to:
  /// **'Client Secretary'**
  String get roleClientSecretary;

  /// No description provided for @roleDispatcher.
  ///
  /// In en, this message translates to:
  /// **'Dispatcher'**
  String get roleDispatcher;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get roleSuperAdmin;

  /// Shown in a snackbar when the backend PUT /users/{id} call to persist the preferred language fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save language to your account'**
  String get languageSaveFailed;

  /// No description provided for @billingScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billingScreenTitle;

  /// No description provided for @invoicesTab.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoicesTab;

  /// No description provided for @companiesTab.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get companiesTab;

  /// No description provided for @billingRidesTab.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get billingRidesTab;

  /// No description provided for @invoicesCountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{month} · {count} Invoices'**
  String invoicesCountSubtitle(String month, int count);

  /// No description provided for @outstandingInvoices.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstandingInvoices;

  /// No description provided for @paidThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Paid (Month)'**
  String get paidThisMonth;

  /// No description provided for @overdueInvoices.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueInvoices;

  /// No description provided for @collectionRate.
  ///
  /// In en, this message translates to:
  /// **'Collection Rate'**
  String get collectionRate;

  /// No description provided for @exportDatevButton.
  ///
  /// In en, this message translates to:
  /// **'Export DATEV'**
  String get exportDatevButton;

  /// No description provided for @createNewInvoiceButton.
  ///
  /// In en, this message translates to:
  /// **'+ New Invoice'**
  String get createNewInvoiceButton;

  /// No description provided for @datevExportOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening DATEV Export...'**
  String get datevExportOpening;

  /// No description provided for @createCompanyFirst.
  ///
  /// In en, this message translates to:
  /// **'Please create a company first.'**
  String get createCompanyFirst;

  /// No description provided for @newInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'New Invoice'**
  String get newInvoiceTitle;

  /// No description provided for @companiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Company *'**
  String get companiesLabel;

  /// No description provided for @createInvoiceButton.
  ///
  /// In en, this message translates to:
  /// **'Create Invoice'**
  String get createInvoiceButton;

  /// No description provided for @allInvoicesFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allInvoicesFilter;

  /// No description provided for @draftStatusFilter.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draftStatusFilter;

  /// No description provided for @sentStatusFilter.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sentStatusFilter;

  /// No description provided for @paidStatusFilter.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidStatusFilter;

  /// No description provided for @invoiceTableHeaderNumber.
  ///
  /// In en, this message translates to:
  /// **'INVOICE'**
  String get invoiceTableHeaderNumber;

  /// No description provided for @invoiceTableHeaderClient.
  ///
  /// In en, this message translates to:
  /// **'CLIENT'**
  String get invoiceTableHeaderClient;

  /// No description provided for @invoiceTableHeaderAmount.
  ///
  /// In en, this message translates to:
  /// **'AMOUNT'**
  String get invoiceTableHeaderAmount;

  /// No description provided for @overdueStatus.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueStatus;

  /// No description provided for @paymentReminderSent.
  ///
  /// In en, this message translates to:
  /// **'Payment reminder sent'**
  String get paymentReminderSent;

  /// No description provided for @viewDetailsMenu.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get viewDetailsMenu;

  /// No description provided for @gobdCompliant.
  ///
  /// In en, this message translates to:
  /// **'GoBD-compliant — invoices are immutably archived.'**
  String get gobdCompliant;

  /// No description provided for @noCompanies.
  ///
  /// In en, this message translates to:
  /// **'No Companies'**
  String get noCompanies;

  /// No description provided for @noInvoices.
  ///
  /// In en, this message translates to:
  /// **'No Invoices'**
  String get noInvoices;

  /// No description provided for @editCompanyMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editCompanyMenu;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @deleteCompanyMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteCompanyMenu;

  /// No description provided for @addCompanyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Company'**
  String get addCompanyTitle;

  /// No description provided for @editCompanyTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Company'**
  String get editCompanyTitle;

  /// No description provided for @companyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get companyNameLabel;

  /// No description provided for @companyEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'E-Mail'**
  String get companyEmailLabel;

  /// No description provided for @companyPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get companyPhoneLabel;

  /// No description provided for @companyAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get companyAddressLabel;

  /// No description provided for @companyVatIdLabel.
  ///
  /// In en, this message translates to:
  /// **'VAT ID (USt-IdNr.)'**
  String get companyVatIdLabel;

  /// No description provided for @invoiceLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice Language'**
  String get invoiceLanguageLabel;

  /// No description provided for @languageStandard.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get languageStandard;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get languageUkrainian;

  /// No description provided for @addCompanyButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addCompanyButton;

  /// No description provided for @deleteCompanyConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Company?'**
  String get deleteCompanyConfirmTitle;

  /// No description provided for @deleteCompanyConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'{name} will be deleted.'**
  String deleteCompanyConfirmMsg(String name);

  /// No description provided for @downloadPdfTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadPdfTooltip;

  /// No description provided for @closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeTooltip;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @pdfPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview · {number}'**
  String pdfPreviewTitle(String number);

  /// No description provided for @invoiceLineItems.
  ///
  /// In en, this message translates to:
  /// **'Line Items'**
  String get invoiceLineItems;

  /// No description provided for @subtotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotalLabel;

  /// No description provided for @vatLineLabel.
  ///
  /// In en, this message translates to:
  /// **'VAT {rate}%'**
  String vatLineLabel(String rate);

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total ({currency})'**
  String totalLabel(String currency);

  /// No description provided for @autoFillRidesButton.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill rides'**
  String get autoFillRidesButton;

  /// No description provided for @sendInvoiceButton.
  ///
  /// In en, this message translates to:
  /// **'Send Invoice'**
  String get sendInvoiceButton;

  /// No description provided for @markAsPaidButton.
  ///
  /// In en, this message translates to:
  /// **'Mark as Paid'**
  String get markAsPaidButton;

  /// No description provided for @pdfDownloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'PDF downloaded'**
  String get pdfDownloadSuccess;

  /// No description provided for @downloadPdfButton.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdfButton;

  /// No description provided for @previewButton.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewButton;

  /// No description provided for @reminderBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminded {date}'**
  String reminderBadgeLabel(String date);

  /// No description provided for @invoicesRailLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoicesRailLabel;

  /// No description provided for @clientsRailLabel.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clientsRailLabel;

  /// No description provided for @datevRailLabel.
  ///
  /// In en, this message translates to:
  /// **'DATEV'**
  String get datevRailLabel;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String genericError(String error);

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Please check your internet connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again in a moment.'**
  String get errorServer;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find what you were looking for.'**
  String get errorNotFound;

  /// No description provided for @errorLoadingData.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the data'**
  String get errorLoadingData;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @unbilledRidesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unbilled Rides'**
  String get unbilledRidesTitle;

  /// No description provided for @selectRidesToBill.
  ///
  /// In en, this message translates to:
  /// **'Select rides to bill'**
  String get selectRidesToBill;

  /// No description provided for @ridesBillingCountSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String ridesBillingCountSelected(int count);

  /// No description provided for @ridesBillingCountAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} rides'**
  String ridesBillingCountAvailable(int count);

  /// No description provided for @selectCompanyForBilling.
  ///
  /// In en, this message translates to:
  /// **'Select a company to see billable rides.'**
  String get selectCompanyForBilling;

  /// No description provided for @noBillableRides.
  ///
  /// In en, this message translates to:
  /// **'No billable rides'**
  String get noBillableRides;

  /// No description provided for @receiptTooltip.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTooltip;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// No description provided for @selectedRidesSummary.
  ///
  /// In en, this message translates to:
  /// **'Selected: {subtotal} net · {total} total'**
  String selectedRidesSummary(String subtotal, String total);

  /// No description provided for @noRidesSelected.
  ///
  /// In en, this message translates to:
  /// **'No rides selected'**
  String get noRidesSelected;

  /// No description provided for @vatPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'VAT %'**
  String get vatPercentLabel;

  /// No description provided for @invoiceCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice Created'**
  String get invoiceCreatedTitle;

  /// No description provided for @invoiceCreatedMsg.
  ///
  /// In en, this message translates to:
  /// **'{number} · {count} rides · €{amount}'**
  String invoiceCreatedMsg(String number, int count, String amount);

  /// No description provided for @pdfDownloadError.
  ///
  /// In en, this message translates to:
  /// **'PDF error: {error}'**
  String pdfDownloadError(String error);

  /// No description provided for @receiptDownloadError.
  ///
  /// In en, this message translates to:
  /// **'Receipt error: {error}'**
  String receiptDownloadError(String error);

  /// No description provided for @datevExportTitle.
  ///
  /// In en, this message translates to:
  /// **'DATEV Export'**
  String get datevExportTitle;

  /// No description provided for @noDataForMonth.
  ///
  /// In en, this message translates to:
  /// **'No data for {monthLabel}'**
  String noDataForMonth(String monthLabel);

  /// No description provided for @revenueSection.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenueSection;

  /// No description provided for @rowsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} rows'**
  String rowsCountLabel(int count);

  /// No description provided for @copyCsvTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy CSV'**
  String get copyCsvTooltip;

  /// No description provided for @revenueCsvLabel.
  ///
  /// In en, this message translates to:
  /// **'Revenue CSV'**
  String get revenueCsvLabel;

  /// No description provided for @expensesSection.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesSection;

  /// No description provided for @expensesCsvLabel.
  ///
  /// In en, this message translates to:
  /// **'Expenses CSV'**
  String get expensesCsvLabel;

  /// No description provided for @summarySection.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summarySection;

  /// No description provided for @netIncomeResult.
  ///
  /// In en, this message translates to:
  /// **'Result: {amount}'**
  String netIncomeResult(String amount);

  /// No description provided for @copySummaryCsvTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy Summary'**
  String get copySummaryCsvTooltip;

  /// No description provided for @summaryCsvLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryCsvLabel;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String copiedToClipboard(String label);

  /// No description provided for @copyAllRevenueHeader.
  ///
  /// In en, this message translates to:
  /// **'=== Revenue ==='**
  String get copyAllRevenueHeader;

  /// No description provided for @copyAllExpensesHeader.
  ///
  /// In en, this message translates to:
  /// **'=== Expenses ==='**
  String get copyAllExpensesHeader;

  /// No description provided for @copyAllSummaryHeader.
  ///
  /// In en, this message translates to:
  /// **'=== Summary ==='**
  String get copyAllSummaryHeader;

  /// No description provided for @allDatevDataLabel.
  ///
  /// In en, this message translates to:
  /// **'All DATEV Data'**
  String get allDatevDataLabel;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {code}'**
  String downloadFailed(String code);

  /// No description provided for @netIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Net Income'**
  String get netIncomeLabel;

  /// No description provided for @copyAllButton.
  ///
  /// In en, this message translates to:
  /// **'Copy All'**
  String get copyAllButton;

  /// No description provided for @downloadCsvExtfButton.
  ///
  /// In en, this message translates to:
  /// **'Download .csv (EXTF)'**
  String get downloadCsvExtfButton;

  /// No description provided for @datevExtfFormatInfo.
  ///
  /// In en, this message translates to:
  /// **'DATEV Buchungsstapel Format – Import via DATEV Unternehmen Online'**
  String get datevExtfFormatInfo;

  /// No description provided for @expensesScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses · {monthLabel}'**
  String expensesScreenTitle(String monthLabel);

  /// No description provided for @addExpenseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Record Expense'**
  String get addExpenseTooltip;

  /// No description provided for @captureExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Expense'**
  String get captureExpenseTitle;

  /// No description provided for @expenseCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expenseCategoryLabel;

  /// No description provided for @expenseAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (EUR)'**
  String get expenseAmountLabel;

  /// No description provided for @expenseDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get expenseDescriptionLabel;

  /// No description provided for @invalidAmountError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get invalidAmountError;

  /// No description provided for @deleteExpenseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Expense?'**
  String get deleteExpenseConfirmTitle;

  /// No description provided for @deleteExpenseConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'{category} · €{amount} will be deleted.'**
  String deleteExpenseConfirmMsg(String category, String amount);

  /// No description provided for @noExpenses.
  ///
  /// In en, this message translates to:
  /// **'No Expenses'**
  String get noExpenses;

  /// No description provided for @noReceiptWarning.
  ///
  /// In en, this message translates to:
  /// **'No Receipt'**
  String get noReceiptWarning;

  /// No description provided for @totalExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalExpensesLabel;

  /// No description provided for @newRideAssigned.
  ///
  /// In en, this message translates to:
  /// **'New ride assigned'**
  String get newRideAssigned;

  /// No description provided for @newRideAssignedContent.
  ///
  /// In en, this message translates to:
  /// **'You have been assigned a new ride. Do you accept it?'**
  String get newRideAssignedContent;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @sms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get sms;

  /// No description provided for @completeRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Ride'**
  String get completeRideTitle;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// Tooltip/label for the action that opens the in-app map bound to this ride
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get viewRideOnMap;

  /// No description provided for @navigateTo.
  ///
  /// In en, this message translates to:
  /// **'Navigate to'**
  String get navigateTo;

  /// No description provided for @googleMapsPickup.
  ///
  /// In en, this message translates to:
  /// **'Google Maps — Pickup'**
  String get googleMapsPickup;

  /// No description provided for @googleMapsDropoff.
  ///
  /// In en, this message translates to:
  /// **'Google Maps — Drop-off'**
  String get googleMapsDropoff;

  /// No description provided for @openingNavigation.
  ///
  /// In en, this message translates to:
  /// **'Opening navigation in Google Maps...'**
  String get openingNavigation;

  /// No description provided for @arrivingInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Arriving in {etaMinutes} min'**
  String arrivingInMinutes(int etaMinutes);

  /// No description provided for @noCompletedRides.
  ///
  /// In en, this message translates to:
  /// **'No completed rides yet'**
  String get noCompletedRides;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Tooltip for the manual flight-status refresh button on the ride flight card
  ///
  /// In en, this message translates to:
  /// **'Refresh flight status'**
  String get refreshFlightStatus;

  /// No description provided for @flightStatusRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Flight status updated'**
  String get flightStatusRefreshed;

  /// No description provided for @flightStatusUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get flightStatusUnchanged;

  /// No description provided for @flightNotFoundYet.
  ///
  /// In en, this message translates to:
  /// **'Flight not in the system yet'**
  String get flightNotFoundYet;

  /// No description provided for @failedToRefreshFlightStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh flight status'**
  String get failedToRefreshFlightStatus;

  /// No description provided for @youreOnline.
  ///
  /// In en, this message translates to:
  /// **'You\'re online'**
  String get youreOnline;

  /// No description provided for @youreOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get youreOffline;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved ride details. If you leave, they will be lost.'**
  String get discardChangesMessage;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @bookLabel.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bookLabel;

  /// No description provided for @monthView.
  ///
  /// In en, this message translates to:
  /// **'Month View'**
  String get monthView;

  /// No description provided for @weekView.
  ///
  /// In en, this message translates to:
  /// **'Week View'**
  String get weekView;

  /// No description provided for @dayView.
  ///
  /// In en, this message translates to:
  /// **'Day View'**
  String get dayView;

  /// No description provided for @board.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get board;

  /// No description provided for @goToday.
  ///
  /// In en, this message translates to:
  /// **'Go to Today'**
  String get goToday;

  /// No description provided for @todaysSchedule.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Schedule'**
  String get todaysSchedule;

  /// No description provided for @noRidesScheduled.
  ///
  /// In en, this message translates to:
  /// **'No rides scheduled'**
  String get noRidesScheduled;

  /// No description provided for @enjoyYourFreeDay.
  ///
  /// In en, this message translates to:
  /// **'Enjoy your free day!'**
  String get enjoyYourFreeDay;

  /// No description provided for @callClient.
  ///
  /// In en, this message translates to:
  /// **'Call Client'**
  String get callClient;

  /// No description provided for @startNavigation.
  ///
  /// In en, this message translates to:
  /// **'Start Navigation'**
  String get startNavigation;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @completeRideButton.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get completeRideButton;

  /// No description provided for @pickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup location'**
  String get pickupLocation;

  /// No description provided for @dropoffLocation.
  ///
  /// In en, this message translates to:
  /// **'Drop-off location'**
  String get dropoffLocation;

  /// No description provided for @couldNotOpenNavigation.
  ///
  /// In en, this message translates to:
  /// **'Could not open navigation: {error}'**
  String couldNotOpenNavigation(String error);

  /// No description provided for @travelTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min travel time'**
  String travelTimeMinutes(int minutes);

  /// No description provided for @failedToSetPrice.
  ///
  /// In en, this message translates to:
  /// **'Failed to set price: {error}'**
  String failedToSetPrice(String error);

  /// No description provided for @setRidePrice.
  ///
  /// In en, this message translates to:
  /// **'Set ride price'**
  String get setRidePrice;

  /// No description provided for @setPrice.
  ///
  /// In en, this message translates to:
  /// **'Set price'**
  String get setPrice;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @acceptingRides.
  ///
  /// In en, this message translates to:
  /// **'You are accepting rides'**
  String get acceptingRides;

  /// No description provided for @notAcceptingRides.
  ///
  /// In en, this message translates to:
  /// **'You are not accepting rides'**
  String get notAcceptingRides;

  /// No description provided for @failedToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Failed to update: {error}'**
  String failedToUpdate(String error);

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @scheduleTab.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleTab;

  /// No description provided for @calendarTab.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTab;

  /// No description provided for @newRideTab.
  ///
  /// In en, this message translates to:
  /// **'New Ride'**
  String get newRideTab;

  /// No description provided for @moreTab.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTab;

  /// No description provided for @billingTab.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billingTab;

  /// No description provided for @moreScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreScreenTitle;

  /// No description provided for @pickupSignMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Pickup Sign'**
  String get pickupSignMenuItem;

  /// No description provided for @pickupSignTitle.
  ///
  /// In en, this message translates to:
  /// **'Pickup Sign'**
  String get pickupSignTitle;

  /// No description provided for @pickupSignHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name or text…'**
  String get pickupSignHint;

  /// No description provided for @pickupSignShowButton.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get pickupSignShowButton;

  /// No description provided for @dispatchBoardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dispatch board'**
  String get dispatchBoardTitle;

  /// No description provided for @dispatcherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {date} · {count} active rides'**
  String dispatcherSubtitle(String weekday, String date, int count);

  /// No description provided for @searchRidesDrivers.
  ///
  /// In en, this message translates to:
  /// **'Search rides, drivers…'**
  String get searchRidesDrivers;

  /// No description provided for @newRideButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'New ride'**
  String get newRideButtonLabel;

  /// No description provided for @activeRidesLabel.
  ///
  /// In en, this message translates to:
  /// **'Active rides'**
  String get activeRidesLabel;

  /// No description provided for @atRiskLabel.
  ///
  /// In en, this message translates to:
  /// **'At risk'**
  String get atRiskLabel;

  /// No description provided for @driversOnlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Drivers online'**
  String get driversOnlineLabel;

  /// No description provided for @onTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'On-time'**
  String get onTimeLabel;

  /// No description provided for @earningsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earningsMenuItem;

  /// No description provided for @peakHoursMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Peak Hours'**
  String get peakHoursMenuItem;

  /// No description provided for @clientValueMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Client Value'**
  String get clientValueMenuItem;

  /// No description provided for @driversMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get driversMenuItem;

  /// No description provided for @ratingsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get ratingsMenuItem;

  /// No description provided for @auditLogMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Audit Log'**
  String get auditLogMenuItem;

  /// No description provided for @adminMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminMenuItem;

  /// No description provided for @companyMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get companyMenuItem;

  /// No description provided for @expensesMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesMenuItem;

  /// No description provided for @exportMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportMenuItem;

  /// No description provided for @templatesMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templatesMenuItem;

  /// No description provided for @paymentsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsMenuItem;

  /// No description provided for @payrollMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Payroll'**
  String get payrollMenuItem;

  /// No description provided for @settingsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsMenuItem;

  /// No description provided for @geofencesMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Geofences'**
  String get geofencesMenuItem;

  /// No description provided for @datevMenuItem.
  ///
  /// In en, this message translates to:
  /// **'DATEV'**
  String get datevMenuItem;

  /// No description provided for @blacklistMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Blacklist'**
  String get blacklistMenuItem;

  /// No description provided for @emergencyMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergencyMenuItem;

  /// No description provided for @ridePoolsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Ride Pools'**
  String get ridePoolsMenuItem;

  /// No description provided for @notificationsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsMenuItem;

  /// No description provided for @gdprMenuItem.
  ///
  /// In en, this message translates to:
  /// **'GDPR'**
  String get gdprMenuItem;

  /// No description provided for @sessionsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsMenuItem;

  /// No description provided for @schedVisibilityMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Sched. Visibility'**
  String get schedVisibilityMenuItem;

  /// No description provided for @analyticsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsMenuItem;

  /// No description provided for @driverBoardMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Driver Board'**
  String get driverBoardMenuItem;

  /// No description provided for @driverMapMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Driver Map'**
  String get driverMapMenuItem;

  /// No description provided for @assignRideDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign Ride · {client}'**
  String assignRideDialogTitle(String client);

  /// No description provided for @rideDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ride details'**
  String get rideDetailsLabel;

  /// No description provided for @clientLabel.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get clientLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @toLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toLabel;

  /// No description provided for @flightLabel.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get flightLabel;

  /// No description provided for @fareLabel.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get fareLabel;

  /// No description provided for @assigningToLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigning to'**
  String get assigningToLabel;

  /// No description provided for @scheduleConflictsCount.
  ///
  /// In en, this message translates to:
  /// **'Schedule conflicts ({count})'**
  String scheduleConflictsCount(int count);

  /// No description provided for @assignDriverButton.
  ///
  /// In en, this message translates to:
  /// **'Assign driver'**
  String get assignDriverButton;

  /// No description provided for @reassignRideDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reassign ride · {client}'**
  String reassignRideDialogTitle(String client);

  /// No description provided for @nearestAvailableDriversLabel.
  ///
  /// In en, this message translates to:
  /// **'NEAREST AVAILABLE DRIVERS · RANKED BY ETA'**
  String get nearestAvailableDriversLabel;

  /// No description provided for @noDriversAvailableForReassignment.
  ///
  /// In en, this message translates to:
  /// **'No other drivers available for reassignment.'**
  String get noDriversAvailableForReassignment;

  /// No description provided for @reassignNRides.
  ///
  /// In en, this message translates to:
  /// **'Reassign {count} ride(s)'**
  String reassignNRides(int count);

  /// No description provided for @driverDelayedMessage.
  ///
  /// In en, this message translates to:
  /// **'{driverName} is delayed — slack {slack} min'**
  String driverDelayedMessage(String driverName, String slack);

  /// No description provided for @ridesToReassignLabel.
  ///
  /// In en, this message translates to:
  /// **'Rides to reassign ({selected}/{total})'**
  String ridesToReassignLabel(int selected, int total);

  /// No description provided for @deselectAllButton.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAllButton;

  /// No description provided for @selectAllButton.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAllButton;

  /// No description provided for @bestMatchBadge.
  ///
  /// In en, this message translates to:
  /// **'Best match'**
  String get bestMatchBadge;

  /// No description provided for @stillLateLabel.
  ///
  /// In en, this message translates to:
  /// **'still late'**
  String get stillLateLabel;

  /// No description provided for @slackRestoredLabel.
  ///
  /// In en, this message translates to:
  /// **'slack restored'**
  String get slackRestoredLabel;

  /// No description provided for @tightLabel.
  ///
  /// In en, this message translates to:
  /// **'tight'**
  String get tightLabel;

  /// No description provided for @ridesReassignedMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} ride(s) reassigned to {driverName}'**
  String ridesReassignedMessage(int count, String driverName);

  /// No description provided for @reassignAnyway.
  ///
  /// In en, this message translates to:
  /// **'Reassign anyway'**
  String get reassignAnyway;

  /// No description provided for @pendingTab.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingTab;

  /// No description provided for @assignedTab.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assignedTab;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTooltip;

  /// No description provided for @noAssignedRides.
  ///
  /// In en, this message translates to:
  /// **'No assigned rides'**
  String get noAssignedRides;

  /// No description provided for @noRidesCurrentlyAssigned.
  ///
  /// In en, this message translates to:
  /// **'No rides currently assigned to drivers'**
  String get noRidesCurrentlyAssigned;

  /// No description provided for @pendingRequestsHeader.
  ///
  /// In en, this message translates to:
  /// **'Pending requests'**
  String get pendingRequestsHeader;

  /// No description provided for @unassignedRidesBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} unassigned'**
  String unassignedRidesBadge(int count);

  /// No description provided for @rideAtRiskTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride at risk of delay'**
  String get rideAtRiskTitle;

  /// No description provided for @etaMonitorBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'PREDICTIVE ETA MONITOR · 60S'**
  String get etaMonitorBadgeLabel;

  /// No description provided for @viewButton.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewButton;

  /// No description provided for @etaDriverEtaLabel.
  ///
  /// In en, this message translates to:
  /// **'DRIVER ETA'**
  String get etaDriverEtaLabel;

  /// No description provided for @etaPickupInLabel.
  ///
  /// In en, this message translates to:
  /// **'PICKUP IN'**
  String get etaPickupInLabel;

  /// No description provided for @etaSlackLabel.
  ///
  /// In en, this message translates to:
  /// **'SLACK'**
  String get etaSlackLabel;

  /// No description provided for @driverEarningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Earnings'**
  String get driverEarningsTitle;

  /// No description provided for @sortByEarnings.
  ///
  /// In en, this message translates to:
  /// **'Sort by Earnings'**
  String get sortByEarnings;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Sort by Name'**
  String get sortByName;

  /// No description provided for @sortByRides.
  ///
  /// In en, this message translates to:
  /// **'Sort by Rides'**
  String get sortByRides;

  /// No description provided for @driverPayrollTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Payroll'**
  String get driverPayrollTitle;

  /// No description provided for @payrollSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Payroll Summary'**
  String get payrollSummaryTitle;

  /// No description provided for @loadPayrollButton.
  ///
  /// In en, this message translates to:
  /// **'Load Payroll'**
  String get loadPayrollButton;

  /// No description provided for @payrollCsvCopiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Payroll CSV copied to clipboard'**
  String get payrollCsvCopiedMessage;

  /// No description provided for @commissionLabel.
  ///
  /// In en, this message translates to:
  /// **'Commission: '**
  String get commissionLabel;

  /// No description provided for @rideStatusHandedOff.
  ///
  /// In en, this message translates to:
  /// **'Handed Off'**
  String get rideStatusHandedOff;

  /// No description provided for @handOffRide.
  ///
  /// In en, this message translates to:
  /// **'Hand Off Ride'**
  String get handOffRide;

  /// No description provided for @handOffRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand Off Ride'**
  String get handOffRideTitle;

  /// No description provided for @handOffPartnerCompany.
  ///
  /// In en, this message translates to:
  /// **'Partner Company'**
  String get handOffPartnerCompany;

  /// No description provided for @handOffExternalDriver.
  ///
  /// In en, this message translates to:
  /// **'External Driver'**
  String get handOffExternalDriver;

  /// No description provided for @handOffSelectCompany.
  ///
  /// In en, this message translates to:
  /// **'Select company'**
  String get handOffSelectCompany;

  /// No description provided for @handOffSelectDriver.
  ///
  /// In en, this message translates to:
  /// **'Select driver'**
  String get handOffSelectDriver;

  /// No description provided for @handOffAddNewCompany.
  ///
  /// In en, this message translates to:
  /// **'+ Add new company'**
  String get handOffAddNewCompany;

  /// No description provided for @handOffAddNewDriver.
  ///
  /// In en, this message translates to:
  /// **'+ Add new driver'**
  String get handOffAddNewDriver;

  /// No description provided for @handOffCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Company name *'**
  String get handOffCompanyName;

  /// No description provided for @handOffDriverName.
  ///
  /// In en, this message translates to:
  /// **'Driver name *'**
  String get handOffDriverName;

  /// No description provided for @handOffPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get handOffPhoneOptional;

  /// No description provided for @handOffButton.
  ///
  /// In en, this message translates to:
  /// **'Hand Off'**
  String get handOffButton;

  /// Confirmation snackbar shown to the dispatcher after a ride is successfully handed off to an external partner company/driver.
  ///
  /// In en, this message translates to:
  /// **'Ride handed off to the external partner.'**
  String get rideHandedOffInfo;

  /// Error snackbar shown when a hand-off request is rejected by the backend (e.g. the ride was already taken, or the partner/driver is invalid).
  ///
  /// In en, this message translates to:
  /// **'Hand-off failed: {message}'**
  String handOffFailed(String message);

  /// No description provided for @closeRide.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeRide;

  /// No description provided for @closeRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Close ride?'**
  String get closeRideTitle;

  /// No description provided for @closeRideConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will cancel the unassigned ride. The client will be notified.'**
  String get closeRideConfirmMessage;

  /// No description provided for @closeRideButton.
  ///
  /// In en, this message translates to:
  /// **'Close ride'**
  String get closeRideButton;

  /// No description provided for @confirmRide.
  ///
  /// In en, this message translates to:
  /// **'Confirm Ride'**
  String get confirmRide;

  /// No description provided for @rejectRide.
  ///
  /// In en, this message translates to:
  /// **'Reject Ride'**
  String get rejectRide;

  /// No description provided for @rejectReasonPrompt.
  ///
  /// In en, this message translates to:
  /// **'Reason for rejection'**
  String get rejectReasonPrompt;

  /// No description provided for @rejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectButton;

  /// No description provided for @rejectReasonTooFar.
  ///
  /// In en, this message translates to:
  /// **'Pickup too far'**
  String get rejectReasonTooFar;

  /// No description provided for @rejectReasonBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy with another ride'**
  String get rejectReasonBusy;

  /// No description provided for @rejectReasonBreak.
  ///
  /// In en, this message translates to:
  /// **'On break / end of shift'**
  String get rejectReasonBreak;

  /// No description provided for @rejectReasonVehicleIssue.
  ///
  /// In en, this message translates to:
  /// **'Vehicle issue'**
  String get rejectReasonVehicleIssue;

  /// No description provided for @rejectReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get rejectReasonOther;

  /// No description provided for @rideConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Ride confirmed'**
  String get rideConfirmed;

  /// No description provided for @rideRejected.
  ///
  /// In en, this message translates to:
  /// **'Ride rejected'**
  String get rideRejected;

  /// No description provided for @confirmationRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride confirmation needed'**
  String get confirmationRequestTitle;

  /// No description provided for @confirmationRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Please confirm or reject your assigned ride'**
  String get confirmationRequestBody;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @ridesTab.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get ridesTab;

  /// No description provided for @createTab.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createTab;

  /// No description provided for @frontDeskTitle.
  ///
  /// In en, this message translates to:
  /// **'Front desk'**
  String get frontDeskTitle;

  /// No description provided for @quickBook.
  ///
  /// In en, this message translates to:
  /// **'Quick book'**
  String get quickBook;

  /// No description provided for @bookedToday.
  ///
  /// In en, this message translates to:
  /// **'Booked today'**
  String get bookedToday;

  /// No description provided for @awaitingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirm'**
  String get awaitingConfirm;

  /// No description provided for @activeClientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Active clients'**
  String get activeClientsLabel;

  /// No description provided for @templatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templatesLabel;

  /// No description provided for @todaysBookings.
  ///
  /// In en, this message translates to:
  /// **'Today\'s bookings'**
  String get todaysBookings;

  /// No description provided for @noRidesToday.
  ///
  /// In en, this message translates to:
  /// **'No rides today'**
  String get noRidesToday;

  /// No description provided for @loadRidesToSeeBookings.
  ///
  /// In en, this message translates to:
  /// **'Load rides to see today\'s bookings'**
  String get loadRidesToSeeBookings;

  /// No description provided for @manageClientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Clients'**
  String get manageClientsTitle;

  /// No description provided for @searchClientsHint.
  ///
  /// In en, this message translates to:
  /// **'Search clients...'**
  String get searchClientsHint;

  /// No description provided for @noClientsMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No clients match your search'**
  String get noClientsMatchSearch;

  /// No description provided for @noClientsYet.
  ///
  /// In en, this message translates to:
  /// **'No clients yet'**
  String get noClientsYet;

  /// No description provided for @addClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Client'**
  String get addClientTitle;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @duplicateRideAction.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateRideAction;

  /// No description provided for @deactivateAction.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivateAction;

  /// No description provided for @editClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Client'**
  String get editClientTitle;

  /// No description provided for @clientUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Client updated successfully'**
  String get clientUpdatedSuccess;

  /// No description provided for @clientUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update client. Please try again.'**
  String get clientUpdateFailed;

  /// No description provided for @deactivateClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Client'**
  String get deactivateClientTitle;

  /// No description provided for @deactivateClientConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to deactivate {name}?'**
  String deactivateClientConfirmMsg(String name);

  /// No description provided for @newRideButton.
  ///
  /// In en, this message translates to:
  /// **'New Ride'**
  String get newRideButton;

  /// No description provided for @ridesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'rides'**
  String get ridesCountLabel;

  /// No description provided for @preferredDriverAssigned.
  ///
  /// In en, this message translates to:
  /// **'Preferred driver assigned'**
  String get preferredDriverAssigned;

  /// No description provided for @noRidesYet.
  ///
  /// In en, this message translates to:
  /// **'No rides yet'**
  String get noRidesYet;

  /// No description provided for @clientCompanyFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get clientCompanyFieldLabel;

  /// No description provided for @clientCompanyNone.
  ///
  /// In en, this message translates to:
  /// **'No company'**
  String get clientCompanyNone;

  /// No description provided for @vipClientLabel.
  ///
  /// In en, this message translates to:
  /// **'VIP Client'**
  String get vipClientLabel;

  /// No description provided for @vipClientHelpText.
  ///
  /// In en, this message translates to:
  /// **'Priority service and preferred driver'**
  String get vipClientHelpText;

  /// No description provided for @driverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver: {name}'**
  String driverLabel(String name);

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @totalRidesLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Rides'**
  String get totalRidesLabel;

  /// No description provided for @inProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgressLabel;

  /// No description provided for @requestedLabel.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requestedLabel;

  /// No description provided for @assignedLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assignedLabel;

  /// No description provided for @keyMetrics.
  ///
  /// In en, this message translates to:
  /// **'Key Metrics'**
  String get keyMetrics;

  /// No description provided for @cancellationRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Rate'**
  String get cancellationRateLabel;

  /// No description provided for @statusBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Status Breakdown'**
  String get statusBreakdown;

  /// No description provided for @noRideDataYet.
  ///
  /// In en, this message translates to:
  /// **'No ride data yet'**
  String get noRideDataYet;

  /// No description provided for @noActiveRides.
  ///
  /// In en, this message translates to:
  /// **'You have no active rides'**
  String get noActiveRides;

  /// No description provided for @useBookTabHint.
  ///
  /// In en, this message translates to:
  /// **'Use \"Book\" tab to create one'**
  String get useBookTabHint;

  /// No description provided for @trackDriver.
  ///
  /// In en, this message translates to:
  /// **'Track driver'**
  String get trackDriver;

  /// No description provided for @departureTimeReachedFlight.
  ///
  /// In en, this message translates to:
  /// **'Departure time reached for flight {flightInfo}'**
  String departureTimeReachedFlight(String flightInfo);

  /// No description provided for @failedToCancelRide.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel ride: {error}'**
  String failedToCancelRide(String error);

  /// No description provided for @failedToLoadRides.
  ///
  /// In en, this message translates to:
  /// **'Failed to load rides'**
  String get failedToLoadRides;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning,'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon,'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening,'**
  String get goodEvening;

  /// No description provided for @whereTo.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whereTo;

  /// No description provided for @onTrip.
  ///
  /// In en, this message translates to:
  /// **'On trip'**
  String get onTrip;

  /// No description provided for @driverOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Driver on the way'**
  String get driverOnTheWay;

  /// No description provided for @driverAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver assigned'**
  String get driverAssigned;

  /// No description provided for @yourDriver.
  ///
  /// In en, this message translates to:
  /// **'Your driver'**
  String get yourDriver;

  /// No description provided for @savedPlaces.
  ///
  /// In en, this message translates to:
  /// **'SAVED PLACES'**
  String get savedPlaces;

  /// No description provided for @savedPlaceHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get savedPlaceHome;

  /// No description provided for @savedPlaceOffice.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get savedPlaceOffice;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addAddress;

  /// No description provided for @useThisAddress.
  ///
  /// In en, this message translates to:
  /// **'Use this address'**
  String get useThisAddress;

  /// No description provided for @editAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get editAddress;

  /// No description provided for @removeAddress.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAddress;

  /// No description provided for @removeAddressConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this saved place?'**
  String get removeAddressConfirm;

  /// No description provided for @myAddresses.
  ///
  /// In en, this message translates to:
  /// **'MY ADDRESSES'**
  String get myAddresses;

  /// No description provided for @manageAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get manageAddresses;

  /// No description provided for @addCustomAddress.
  ///
  /// In en, this message translates to:
  /// **'Add new place'**
  String get addCustomAddress;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get addressLabel;

  /// No description provided for @addressLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Gym, Parents'**
  String get addressLabelHint;

  /// No description provided for @labelRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a label'**
  String get labelRequired;

  /// No description provided for @bookARide.
  ///
  /// In en, this message translates to:
  /// **'Book a ride'**
  String get bookARide;

  /// No description provided for @scheduled.
  ///
  /// In en, this message translates to:
  /// **'SCHEDULED'**
  String get scheduled;

  /// No description provided for @nowLabel.
  ///
  /// In en, this message translates to:
  /// **'NOW'**
  String get nowLabel;

  /// No description provided for @asap.
  ///
  /// In en, this message translates to:
  /// **'ASAP'**
  String get asap;

  /// No description provided for @vehicleClass.
  ///
  /// In en, this message translates to:
  /// **'VEHICLE CLASS'**
  String get vehicleClass;

  /// No description provided for @estimatedTotal.
  ///
  /// In en, this message translates to:
  /// **'Estimated total'**
  String get estimatedTotal;

  /// No description provided for @estimateUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t estimate the price for this address. You can still book — the fare will be confirmed afterwards.'**
  String get estimateUnavailableHint;

  /// No description provided for @confirmBooking.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get confirmBooking;

  /// No description provided for @rideBookedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Ride booked successfully!'**
  String get rideBookedSuccessfully;

  /// No description provided for @failedToCreateRide.
  ///
  /// In en, this message translates to:
  /// **'Failed to create ride'**
  String get failedToCreateRide;

  /// No description provided for @failedToLoadRideHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed to load ride history'**
  String get failedToLoadRideHistory;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get listView;

  /// No description provided for @pastLabel.
  ///
  /// In en, this message translates to:
  /// **'PAST'**
  String get pastLabel;

  /// No description provided for @confirmedStatus.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmedStatus;

  /// No description provided for @rateThisRide.
  ///
  /// In en, this message translates to:
  /// **'Rate this ride'**
  String get rateThisRide;

  /// No description provided for @thankYouForRating.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your rating!'**
  String get thankYouForRating;

  /// No description provided for @failedToSubmitRating.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit rating: {error}'**
  String failedToSubmitRating(String error);

  /// No description provided for @rideCardTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String rideCardTimeLabel(String time);

  /// No description provided for @deleteConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get deleteConfirmationTitle;

  /// No description provided for @deleteRideConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete ride {from} → {to}?'**
  String deleteRideConfirmMessage(String from, String to);

  /// No description provided for @cancelRideDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Ride'**
  String get cancelRideDialogTitle;

  /// No description provided for @selectCancellationReason.
  ///
  /// In en, this message translates to:
  /// **'Please select a reason for cancellation:'**
  String get selectCancellationReason;

  /// No description provided for @cancellationReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get cancellationReasonLabel;

  /// No description provided for @cancellationReasonClientRequest.
  ///
  /// In en, this message translates to:
  /// **'Client Request'**
  String get cancellationReasonClientRequest;

  /// No description provided for @cancellationReasonWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get cancellationReasonWeather;

  /// No description provided for @cancellationReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cancellationReasonOther;

  /// No description provided for @cancellationReasonClientNoShow.
  ///
  /// In en, this message translates to:
  /// **'Client No-Show'**
  String get cancellationReasonClientNoShow;

  /// No description provided for @cancellationReasonDriverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Driver Unavailable'**
  String get cancellationReasonDriverUnavailable;

  /// No description provided for @cancellationReasonVehicleIssue.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Issue'**
  String get cancellationReasonVehicleIssue;

  /// No description provided for @cancellationFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Fee (optional)'**
  String get cancellationFeeLabel;

  /// No description provided for @rateRideExperienceQuestion.
  ///
  /// In en, this message translates to:
  /// **'How was your experience?'**
  String get rateRideExperienceQuestion;

  /// No description provided for @rateRideCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get rateRideCommentLabel;

  /// No description provided for @rateRideCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your experience...'**
  String get rateRideCommentHint;

  /// No description provided for @airportTransferLabel.
  ///
  /// In en, this message translates to:
  /// **'Airport Transfer'**
  String get airportTransferLabel;

  /// No description provided for @airportTransferHint.
  ///
  /// In en, this message translates to:
  /// **'Enable if this is an airport pickup/drop-off'**
  String get airportTransferHint;

  /// No description provided for @airportDepartureLabel.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get airportDepartureLabel;

  /// No description provided for @airportDepartureHint.
  ///
  /// In en, this message translates to:
  /// **'To airport'**
  String get airportDepartureHint;

  /// No description provided for @airportArrivalLabel.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get airportArrivalLabel;

  /// No description provided for @airportArrivalHint.
  ///
  /// In en, this message translates to:
  /// **'From airport'**
  String get airportArrivalHint;

  /// No description provided for @flightNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Flight Number'**
  String get flightNumberLabel;

  /// No description provided for @flightNumberHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. LH123, BA456'**
  String get flightNumberHint;

  /// Validation error shown when an airport-transfer ride is missing its flight number
  ///
  /// In en, this message translates to:
  /// **'Flight number is required'**
  String get flightNumberRequired;

  /// Validation error when the entered flight number is not a plausible IATA/ICAO code+number
  ///
  /// In en, this message translates to:
  /// **'Enter a valid flight number, e.g. LH429'**
  String get flightNumberInvalidFormat;

  /// No description provided for @gateLabel.
  ///
  /// In en, this message translates to:
  /// **'Gate'**
  String get gateLabel;

  /// No description provided for @terminalLabel.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminalLabel;

  /// Shown instead of a gate code when MUC reports 'Gate REMOTE' — the plane is on a remote apron stand and passengers are bussed to the terminal.
  ///
  /// In en, this message translates to:
  /// **'Bus gate (remote stand)'**
  String get gateRemote;

  /// No description provided for @creatingRideLabel.
  ///
  /// In en, this message translates to:
  /// **'Creating Ride...'**
  String get creatingRideLabel;

  /// No description provided for @createRideButton.
  ///
  /// In en, this message translates to:
  /// **'Create Ride'**
  String get createRideButton;

  /// No description provided for @clearFormButton.
  ///
  /// In en, this message translates to:
  /// **'Clear Form'**
  String get clearFormButton;

  /// No description provided for @vehicleInformationLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Information'**
  String get vehicleInformationLabel;

  /// No description provided for @messageButton.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageButton;

  /// No description provided for @routeInformationLabel.
  ///
  /// In en, this message translates to:
  /// **'Route Information'**
  String get routeInformationLabel;

  /// No description provided for @pickupTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup Time'**
  String get pickupTimeLabel;

  /// No description provided for @distanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceLabel;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @etaToClientLabel.
  ///
  /// In en, this message translates to:
  /// **'ETA to client'**
  String get etaToClientLabel;

  /// No description provided for @openInGoogleMapsButton.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get openInGoogleMapsButton;

  /// No description provided for @rideStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Ride Status'**
  String get rideStatusLabel;

  /// No description provided for @rideHasBeenCancelledLabel.
  ///
  /// In en, this message translates to:
  /// **'This ride has been cancelled'**
  String get rideHasBeenCancelledLabel;

  /// No description provided for @rideStatusRequestedClientLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver assignment'**
  String get rideStatusRequestedClientLabel;

  /// No description provided for @rideStatusRequestedStaffLabel.
  ///
  /// In en, this message translates to:
  /// **'Awaiting assignment'**
  String get rideStatusRequestedStaffLabel;

  /// No description provided for @rideStatusAssignedEnRouteLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver is on the way'**
  String get rideStatusAssignedEnRouteLabel;

  /// No description provided for @rideStatusAssignedLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver assigned'**
  String get rideStatusAssignedLabel;

  /// No description provided for @rideStatusAssignedDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'You are assigned to this ride'**
  String get rideStatusAssignedDriverLabel;

  /// No description provided for @rideStatusInProgressClientLabel.
  ///
  /// In en, this message translates to:
  /// **'Ride in progress'**
  String get rideStatusInProgressClientLabel;

  /// No description provided for @rideStatusInProgressDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'Drive safely'**
  String get rideStatusInProgressDriverLabel;

  /// No description provided for @rideStatusCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed successfully'**
  String get rideStatusCompletedLabel;

  /// No description provided for @rideStatusCancelledLabel.
  ///
  /// In en, this message translates to:
  /// **'Ride cancelled'**
  String get rideStatusCancelledLabel;

  /// No description provided for @rideStatusHandedOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Handed off to partner'**
  String get rideStatusHandedOffLabel;

  /// No description provided for @rideStatusConfirmedClientLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver confirmed your ride'**
  String get rideStatusConfirmedClientLabel;

  /// No description provided for @rideStatusConfirmedDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'You confirmed this ride'**
  String get rideStatusConfirmedDriverLabel;

  /// No description provided for @rideStatusConfirmedDriverReadyLabel.
  ///
  /// In en, this message translates to:
  /// **'You confirmed this ride — ready to start'**
  String get rideStatusConfirmedDriverReadyLabel;

  /// No description provided for @authenticationRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get authenticationRequiredError;

  /// No description provided for @selectOrCreateClientError.
  ///
  /// In en, this message translates to:
  /// **'Please select or create a client'**
  String get selectOrCreateClientError;

  /// No description provided for @enterClientNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter client name'**
  String get enterClientNameError;

  /// No description provided for @enterFromAddressError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the pickup address'**
  String get enterFromAddressError;

  /// No description provided for @enterToAddressError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the destination address'**
  String get enterToAddressError;

  /// No description provided for @addressesMustDifferError.
  ///
  /// In en, this message translates to:
  /// **'Pickup and destination must be different'**
  String get addressesMustDifferError;

  /// No description provided for @selectPickupTimeError.
  ///
  /// In en, this message translates to:
  /// **'Please select a pickup time'**
  String get selectPickupTimeError;

  /// No description provided for @selectFlightDepartureError.
  ///
  /// In en, this message translates to:
  /// **'Please select the flight departure time'**
  String get selectFlightDepartureError;

  /// No description provided for @editRideDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Ride'**
  String get editRideDialogTitle;

  /// No description provided for @pickupDateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup date/time'**
  String get pickupDateTimeLabel;

  /// No description provided for @flightNumberOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Flight number (optional)'**
  String get flightNumberOptionalLabel;

  /// No description provided for @notesOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptionalLabel;

  /// No description provided for @serverErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Server error: {statusCode}'**
  String serverErrorMessage(String statusCode);

  /// No description provided for @useDispatcherDashboardInfo.
  ///
  /// In en, this message translates to:
  /// **'Use the Dispatcher Dashboard to assign drivers'**
  String get useDispatcherDashboardInfo;

  /// No description provided for @updateLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Location'**
  String get updateLocationTitle;

  /// No description provided for @tellDriverWhereYouAreLabel.
  ///
  /// In en, this message translates to:
  /// **'Tell the driver where you are now:'**
  String get tellDriverWhereYouAreLabel;

  /// No description provided for @quickSelectLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick select:'**
  String get quickSelectLabel;

  /// No description provided for @locationQuickMainEntrance.
  ///
  /// In en, this message translates to:
  /// **'At main entrance'**
  String get locationQuickMainEntrance;

  /// No description provided for @locationQuickBaggageClaim.
  ///
  /// In en, this message translates to:
  /// **'At baggage claim'**
  String get locationQuickBaggageClaim;

  /// No description provided for @locationQuickCafe.
  ///
  /// In en, this message translates to:
  /// **'At cafe'**
  String get locationQuickCafe;

  /// No description provided for @locationQuickParking.
  ///
  /// In en, this message translates to:
  /// **'At parking'**
  String get locationQuickParking;

  /// No description provided for @locationQuickInformationDesk.
  ///
  /// In en, this message translates to:
  /// **'At information desk'**
  String get locationQuickInformationDesk;

  /// No description provided for @locationQuickSecondFloor.
  ///
  /// In en, this message translates to:
  /// **'On second floor'**
  String get locationQuickSecondFloor;

  /// No description provided for @locationQuickExit1.
  ///
  /// In en, this message translates to:
  /// **'At exit #1'**
  String get locationQuickExit1;

  /// No description provided for @locationQuickExit2.
  ///
  /// In en, this message translates to:
  /// **'At exit #2'**
  String get locationQuickExit2;

  /// No description provided for @locationQuickOther.
  ///
  /// In en, this message translates to:
  /// **'Other location'**
  String get locationQuickOther;

  /// No description provided for @orSpecifyExactlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Or specify exactly:'**
  String get orSpecifyExactlyLabel;

  /// No description provided for @locationExampleHint.
  ///
  /// In en, this message translates to:
  /// **'Example: \"At Terminal A entrance\"'**
  String get locationExampleHint;

  /// No description provided for @additionalInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Additional instructions (optional):'**
  String get additionalInstructionsLabel;

  /// No description provided for @additionalInstructionsExampleHint.
  ///
  /// In en, this message translates to:
  /// **'Example: \"Standing near the coffee shop\"'**
  String get additionalInstructionsExampleHint;

  /// No description provided for @specifyLocationError.
  ///
  /// In en, this message translates to:
  /// **'Please specify your location'**
  String get specifyLocationError;

  /// No description provided for @failedToUpdateLocationError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update location. Please try again.'**
  String get failedToUpdateLocationError;

  /// No description provided for @callClientTooltip.
  ///
  /// In en, this message translates to:
  /// **'Call Client'**
  String get callClientTooltip;

  /// No description provided for @navigateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigateTooltip;

  /// No description provided for @delayByHowLongTitle.
  ///
  /// In en, this message translates to:
  /// **'Delay by how long?'**
  String get delayByHowLongTitle;

  /// No description provided for @minutesLabel.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String minutesLabel(int minutes);

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Mobility Solutions'**
  String get appSubtitle;

  /// No description provided for @orLabel.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orLabel;

  /// No description provided for @touchIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Touch ID'**
  String get touchIdLabel;

  /// No description provided for @biometricsLabel.
  ///
  /// In en, this message translates to:
  /// **'Biometrics'**
  String get biometricsLabel;

  /// No description provided for @biometricSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric Setup'**
  String get biometricSetupTitle;

  /// No description provided for @biometricSetupMessage.
  ///
  /// In en, this message translates to:
  /// **'Would you like to enable quick login using biometrics?\n\nThis will allow you to sign in using Face ID, Touch ID, or fingerprint.'**
  String get biometricSetupMessage;

  /// No description provided for @laterButton.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get laterButton;

  /// No description provided for @enableButton.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enableButton;

  /// No description provided for @createButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createButton;

  /// No description provided for @allLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String operationFailed(String error);

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @addGeofenceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add geofence'**
  String get addGeofenceTooltip;

  /// No description provided for @savedTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved templates'**
  String get savedTemplatesTitle;

  /// No description provided for @createTemplateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Template'**
  String get createTemplateDialogTitle;

  /// No description provided for @templateNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get templateNameLabel;

  /// No description provided for @fromAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'From Address'**
  String get fromAddressLabel;

  /// No description provided for @toAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'To Address'**
  String get toAddressLabel;

  /// No description provided for @templatePickupTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup Time (HH:mm)'**
  String get templatePickupTimeLabel;

  /// No description provided for @recurrenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Recurrence'**
  String get recurrenceLabel;

  /// No description provided for @recurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get recurrenceWeekdays;

  /// No description provided for @recurrenceWeeklyMonday.
  ///
  /// In en, this message translates to:
  /// **'Weekly Monday'**
  String get recurrenceWeeklyMonday;

  /// No description provided for @recurrenceWeeklyTuesday.
  ///
  /// In en, this message translates to:
  /// **'Weekly Tuesday'**
  String get recurrenceWeeklyTuesday;

  /// No description provided for @recurrenceWeeklyWednesday.
  ///
  /// In en, this message translates to:
  /// **'Weekly Wednesday'**
  String get recurrenceWeeklyWednesday;

  /// No description provided for @recurrenceWeeklyThursday.
  ///
  /// In en, this message translates to:
  /// **'Weekly Thursday'**
  String get recurrenceWeeklyThursday;

  /// No description provided for @recurrenceWeeklyFriday.
  ///
  /// In en, this message translates to:
  /// **'Weekly Friday'**
  String get recurrenceWeeklyFriday;

  /// No description provided for @recurrenceSaturdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekly Saturday'**
  String get recurrenceSaturdayLabel;

  /// No description provided for @recurrenceSundayLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekly Sunday'**
  String get recurrenceSundayLabel;

  /// No description provided for @priceOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Price (optional)'**
  String get priceOptionalLabel;

  /// No description provided for @generateRidesMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'Generate rides'**
  String get generateRidesMenuLabel;

  /// No description provided for @deactivateTemplateMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivateTemplateMenuLabel;

  /// No description provided for @noTemplatesYet.
  ///
  /// In en, this message translates to:
  /// **'No templates yet'**
  String get noTemplatesYet;

  /// No description provided for @noTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a template to schedule recurring rides'**
  String get noTemplatesSubtitle;

  /// No description provided for @addTemplateButton.
  ///
  /// In en, this message translates to:
  /// **'Add template'**
  String get addTemplateButton;

  /// No description provided for @ridesGeneratedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Rides generated successfully'**
  String get ridesGeneratedSuccess;

  /// No description provided for @failedToGenerateRides.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate rides: {error}'**
  String failedToGenerateRides(String error);

  /// No description provided for @failedToDeactivateTemplate.
  ///
  /// In en, this message translates to:
  /// **'Failed to deactivate: {error}'**
  String failedToDeactivateTemplate(String error);

  /// No description provided for @templateBadgeActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get templateBadgeActive;

  /// No description provided for @templateBadgePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get templateBadgePaused;

  /// No description provided for @geofenceScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Geofences'**
  String get geofenceScreenTitle;

  /// No description provided for @zonesTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get zonesTabLabel;

  /// No description provided for @recentAlertsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent Alerts'**
  String get recentAlertsTabLabel;

  /// No description provided for @createGeofenceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Geofence'**
  String get createGeofenceDialogTitle;

  /// No description provided for @zoneNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Zone name'**
  String get zoneNameLabel;

  /// No description provided for @geofenceTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get geofenceTypeLabel;

  /// No description provided for @geofenceTypeServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Service Area'**
  String get geofenceTypeServiceArea;

  /// No description provided for @geofenceTypeClientPickup.
  ///
  /// In en, this message translates to:
  /// **'Client Pickup'**
  String get geofenceTypeClientPickup;

  /// No description provided for @geofenceTypeCustomZone.
  ///
  /// In en, this message translates to:
  /// **'Custom Zone'**
  String get geofenceTypeCustomZone;

  /// No description provided for @latitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get latitudeLabel;

  /// No description provided for @longitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitudeLabel;

  /// No description provided for @radiusLabel.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get radiusLabel;

  /// No description provided for @notifyOnEntryLabel.
  ///
  /// In en, this message translates to:
  /// **'Notify on entry'**
  String get notifyOnEntryLabel;

  /// No description provided for @notifyOnExitLabel.
  ///
  /// In en, this message translates to:
  /// **'Notify on exit'**
  String get notifyOnExitLabel;

  /// No description provided for @noGeofenceZonesYet.
  ///
  /// In en, this message translates to:
  /// **'No geofence zones yet'**
  String get noGeofenceZonesYet;

  /// No description provided for @createZonesToMonitorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create zones to monitor driver entry and exit events'**
  String get createZonesToMonitorSubtitle;

  /// No description provided for @createZoneButton.
  ///
  /// In en, this message translates to:
  /// **'Create zone'**
  String get createZoneButton;

  /// No description provided for @deleteZoneConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete zone'**
  String get deleteZoneConfirmTitle;

  /// No description provided for @deleteZoneConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteZoneConfirmMsg(String name);

  /// No description provided for @geofenceDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Geofence deleted'**
  String get geofenceDeletedSuccess;

  /// No description provided for @failedToDeleteGeofence.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String failedToDeleteGeofence(String error);

  /// No description provided for @failedToToggleGeofence.
  ///
  /// In en, this message translates to:
  /// **'Failed to toggle geofence ({code})'**
  String failedToToggleGeofence(String code);

  /// No description provided for @failedToCreateGeofence.
  ///
  /// In en, this message translates to:
  /// **'Failed to create geofence ({code})'**
  String failedToCreateGeofence(String code);

  /// No description provided for @geofenceCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Geofence created'**
  String get geofenceCreatedSuccess;

  /// No description provided for @fillRequiredFieldsError.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get fillRequiredFieldsError;

  /// No description provided for @noAlertsFound.
  ///
  /// In en, this message translates to:
  /// **'No alerts found'**
  String get noAlertsFound;

  /// No description provided for @driverEnteredGeofence.
  ///
  /// In en, this message translates to:
  /// **'Driver entered {geofenceName}'**
  String driverEnteredGeofence(String geofenceName);

  /// No description provided for @driverLeftGeofence.
  ///
  /// In en, this message translates to:
  /// **'Driver left {geofenceName}'**
  String driverLeftGeofence(String geofenceName);

  /// No description provided for @alertFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get alertFilterAll;

  /// No description provided for @alertFilterEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get alertFilterEntry;

  /// No description provided for @alertFilterExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get alertFilterExit;

  /// No description provided for @alertFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter:'**
  String get alertFilterLabel;

  /// No description provided for @geofenceSubtitleAirport.
  ///
  /// In en, this message translates to:
  /// **'Airport zone · {radius}m radius'**
  String geofenceSubtitleAirport(int radius);

  /// No description provided for @geofenceSubtitleServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Service area · {radius}m radius'**
  String geofenceSubtitleServiceArea(int radius);

  /// No description provided for @geofenceSubtitleClientPickup.
  ///
  /// In en, this message translates to:
  /// **'Client pickup point · {radius}m radius'**
  String geofenceSubtitleClientPickup(int radius);

  /// No description provided for @geofenceSubtitleCustomZone.
  ///
  /// In en, this message translates to:
  /// **'Custom zone · {radius}m radius'**
  String geofenceSubtitleCustomZone(int radius);

  /// No description provided for @failedToLoadGeofences.
  ///
  /// In en, this message translates to:
  /// **'Failed to load geofences ({code})'**
  String failedToLoadGeofences(String code);

  /// No description provided for @failedToLoadAlerts.
  ///
  /// In en, this message translates to:
  /// **'Failed to load alerts ({code})'**
  String failedToLoadAlerts(String code);

  /// No description provided for @notifTabNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTabNotifications;

  /// No description provided for @notifTabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get notifTabSettings;

  /// No description provided for @markAllReadButton.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllReadButton;

  /// No description provided for @clearAllNotificationsMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAllNotificationsMenuLabel;

  /// No description provided for @clearAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Notifications'**
  String get clearAllConfirmTitle;

  /// No description provided for @clearAllConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all notifications?'**
  String get clearAllConfirmContent;

  /// No description provided for @deleteAllNotificationsButton.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAllNotificationsButton;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotificationsYet;

  /// No description provided for @notifFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notifFilterAll;

  /// No description provided for @notifFilterRides.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get notifFilterRides;

  /// No description provided for @notifFilterChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get notifFilterChat;

  /// No description provided for @notifFilterGeofence.
  ///
  /// In en, this message translates to:
  /// **'Geofence'**
  String get notifFilterGeofence;

  /// No description provided for @notifFilterPools.
  ///
  /// In en, this message translates to:
  /// **'Pools'**
  String get notifFilterPools;

  /// No description provided for @notifFilterCheckpoints.
  ///
  /// In en, this message translates to:
  /// **'Checkpoints'**
  String get notifFilterCheckpoints;

  /// No description provided for @notifJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get notifJustNow;

  /// No description provided for @notifMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String notifMinutesAgo(int count);

  /// No description provided for @notifHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String notifHoursAgo(int count);

  /// No description provided for @notifDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String notifDaysAgo(int count);

  /// No description provided for @notifPrefSectionPush.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get notifPrefSectionPush;

  /// No description provided for @notifPrefSectionAdditional.
  ///
  /// In en, this message translates to:
  /// **'Additional Channels'**
  String get notifPrefSectionAdditional;

  /// No description provided for @notifPrefRideUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Status changes, assignments'**
  String get notifPrefRideUpdatesSubtitle;

  /// No description provided for @notifPrefChatMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New messages from driver/client'**
  String get notifPrefChatMessagesSubtitle;

  /// No description provided for @notifPrefDriverApproachingLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver Approaching'**
  String get notifPrefDriverApproachingLabel;

  /// No description provided for @notifPrefDriverApproachingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When driver is near pickup'**
  String get notifPrefDriverApproachingSubtitle;

  /// No description provided for @notifPrefGeofenceAlertsLabel.
  ///
  /// In en, this message translates to:
  /// **'Geofence Alerts'**
  String get notifPrefGeofenceAlertsLabel;

  /// No description provided for @notifPrefGeofenceAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Entry/exit zone alerts'**
  String get notifPrefGeofenceAlertsSubtitle;

  /// No description provided for @notifPrefPoolUpdatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Pool Updates'**
  String get notifPrefPoolUpdatesLabel;

  /// No description provided for @notifPrefPoolUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ride pooling notifications'**
  String get notifPrefPoolUpdatesSubtitle;

  /// No description provided for @notifPrefEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get notifPrefEmailLabel;

  /// No description provided for @notifPrefEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications via email'**
  String get notifPrefEmailSubtitle;

  /// No description provided for @notifPrefSmsLabel.
  ///
  /// In en, this message translates to:
  /// **'SMS Notifications'**
  String get notifPrefSmsLabel;

  /// No description provided for @notifPrefSmsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications via SMS'**
  String get notifPrefSmsSubtitle;

  /// No description provided for @notifPrefQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet Hours'**
  String get notifPrefQuietHours;

  /// No description provided for @notifPrefQuietHoursFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get notifPrefQuietHoursFrom;

  /// No description provided for @notifPrefQuietHoursTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get notifPrefQuietHoursTo;

  /// No description provided for @notifPrefNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notifPrefNotSet;

  /// No description provided for @savePreferencesButton.
  ///
  /// In en, this message translates to:
  /// **'Save Preferences'**
  String get savePreferencesButton;

  /// No description provided for @preferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved'**
  String get preferencesSaved;

  /// No description provided for @revokeSessionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke Session'**
  String get revokeSessionDialogTitle;

  /// No description provided for @revokeSessionDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will log out the device associated with this session.'**
  String get revokeSessionDialogContent;

  /// No description provided for @revokeSessionButton.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revokeSessionButton;

  /// No description provided for @revokeAllOtherSessionsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke All Other Sessions'**
  String get revokeAllOtherSessionsDialogTitle;

  /// No description provided for @revokeAllOtherSessionsDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will log out all other devices. Only your current session will remain active.'**
  String get revokeAllOtherSessionsDialogContent;

  /// No description provided for @revokeAllButton.
  ///
  /// In en, this message translates to:
  /// **'Revoke All'**
  String get revokeAllButton;

  /// No description provided for @sessionRevoked.
  ///
  /// In en, this message translates to:
  /// **'Session revoked'**
  String get sessionRevoked;

  /// No description provided for @allOtherSessionsRevoked.
  ///
  /// In en, this message translates to:
  /// **'All other sessions revoked'**
  String get allOtherSessionsRevoked;

  /// No description provided for @noActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'No active sessions'**
  String get noActiveSessions;

  /// No description provided for @sessionCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get sessionCurrentLabel;

  /// No description provided for @sessionIpLabel.
  ///
  /// In en, this message translates to:
  /// **'IP: {ip}'**
  String sessionIpLabel(String ip);

  /// No description provided for @sessionCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Created: {date}'**
  String sessionCreatedLabel(String date);

  /// No description provided for @sessionLastActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Last active: {date}'**
  String sessionLastActiveLabel(String date);

  /// No description provided for @revokeSessionAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revokeSessionAction;

  /// No description provided for @userManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userManagementTitle;

  /// No description provided for @createUserDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create User'**
  String get createUserDialogTitle;

  /// No description provided for @searchUsersHint.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get searchUsersHint;

  /// No description provided for @changeRoleMenuHeader.
  ///
  /// In en, this message translates to:
  /// **'Change Role'**
  String get changeRoleMenuHeader;

  /// No description provided for @changeStatusMenuHeader.
  ///
  /// In en, this message translates to:
  /// **'Change Status'**
  String get changeStatusMenuHeader;

  /// No description provided for @activateUserAction.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activateUserAction;

  /// No description provided for @suspendUserAction.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspendUserAction;

  /// No description provided for @deactivateUserAction.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivateUserAction;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @totalUsersLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalUsersLabel;

  /// No description provided for @driversStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get driversStatLabel;

  /// No description provided for @clientsStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clientsStatLabel;

  /// No description provided for @staffStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffStatLabel;

  /// No description provided for @roleChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Role updated to {role}'**
  String roleChangedSuccess(String role);

  /// No description provided for @statusChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Status updated to {status}'**
  String statusChangedSuccess(String status);

  /// No description provided for @failedToChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failedToChangeRole(String error);

  /// No description provided for @failedToChangeStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failedToChangeStatus(String error);

  /// No description provided for @failedToCreateUser.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failedToCreateUser(String error);

  /// No description provided for @blacklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Blacklist'**
  String get blacklistTitle;

  /// No description provided for @addBlacklistEntryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Blacklist Entry'**
  String get addBlacklistEntryDialogTitle;

  /// No description provided for @clientIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get clientIdLabel;

  /// No description provided for @driverIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver ID'**
  String get driverIdLabel;

  /// No description provided for @reasonOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get reasonOptionalLabel;

  /// No description provided for @clientDriverIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Client ID and Driver ID are required'**
  String get clientDriverIdRequired;

  /// No description provided for @removeBlacklistEntryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Blacklist Entry'**
  String get removeBlacklistEntryDialogTitle;

  /// No description provided for @removeBlacklistEntryContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this blacklist entry?'**
  String get removeBlacklistEntryContent;

  /// No description provided for @removeBlacklistEntryButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeBlacklistEntryButton;

  /// No description provided for @noBlacklistEntries.
  ///
  /// In en, this message translates to:
  /// **'No blacklist entries'**
  String get noBlacklistEntries;

  /// No description provided for @tenantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tenants'**
  String get tenantsTitle;

  /// No description provided for @tenantsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Tenants · {count} companies'**
  String tenantsWithCount(int count);

  /// No description provided for @onboardButton.
  ///
  /// In en, this message translates to:
  /// **'+ Onboard'**
  String get onboardButton;

  /// No description provided for @noTenantsFound.
  ///
  /// In en, this message translates to:
  /// **'No tenants found'**
  String get noTenantsFound;

  /// No description provided for @onboardCompanyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Onboard Company'**
  String get onboardCompanyDialogTitle;

  /// No description provided for @editCompanyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Company'**
  String get editCompanyDialogTitle;

  /// No description provided for @subscriptionPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscription Plan'**
  String get subscriptionPlanLabel;

  /// No description provided for @colHeaderCompany.
  ///
  /// In en, this message translates to:
  /// **'COMPANY'**
  String get colHeaderCompany;

  /// No description provided for @colHeaderPlan.
  ///
  /// In en, this message translates to:
  /// **'PLAN'**
  String get colHeaderPlan;

  /// No description provided for @colHeaderDrivers.
  ///
  /// In en, this message translates to:
  /// **'DRIVERS'**
  String get colHeaderDrivers;

  /// No description provided for @colHeaderRidesPerMonth.
  ///
  /// In en, this message translates to:
  /// **'RIDES / MO'**
  String get colHeaderRidesPerMonth;

  /// No description provided for @colHeaderStatus.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get colHeaderStatus;

  /// No description provided for @deactivateCompanyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Company?'**
  String get deactivateCompanyDialogTitle;

  /// No description provided for @deactivateCompanyDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to deactivate \"{name}\"?\n\nThe company will be marked as Inactive but all data (rides, invoices, users) will be preserved.'**
  String deactivateCompanyDialogContent(String name);

  /// No description provided for @setActiveAction.
  ///
  /// In en, this message translates to:
  /// **'Set Active'**
  String get setActiveAction;

  /// No description provided for @setTrialAction.
  ///
  /// In en, this message translates to:
  /// **'Set Trial'**
  String get setTrialAction;

  /// No description provided for @suspendAction.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspendAction;

  /// No description provided for @emergencyReassignmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Reassignments'**
  String get emergencyReassignmentTitle;

  /// No description provided for @emergencyReassignmentDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Reassignment'**
  String get emergencyReassignmentDialogTitle;

  /// No description provided for @rideIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Ride ID'**
  String get rideIdLabel;

  /// No description provided for @emergencyReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get emergencyReasonLabel;

  /// No description provided for @availableDriversLabel.
  ///
  /// In en, this message translates to:
  /// **'Available Drivers:'**
  String get availableDriversLabel;

  /// No description provided for @newDriverIdLabel.
  ///
  /// In en, this message translates to:
  /// **'New Driver ID (optional)'**
  String get newDriverIdLabel;

  /// No description provided for @newDriverIdHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to unassign and return to pending'**
  String get newDriverIdHelper;

  /// No description provided for @reassignButton.
  ///
  /// In en, this message translates to:
  /// **'Reassign'**
  String get reassignButton;

  /// No description provided for @rideIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Ride ID is required'**
  String get rideIdRequired;

  /// No description provided for @emergencyReassignmentCreated.
  ///
  /// In en, this message translates to:
  /// **'Emergency reassignment created'**
  String get emergencyReassignmentCreated;

  /// No description provided for @noEmergencyReassignments.
  ///
  /// In en, this message translates to:
  /// **'No emergency reassignments'**
  String get noEmergencyReassignments;

  /// No description provided for @emergencyReasonDriverIllness.
  ///
  /// In en, this message translates to:
  /// **'Driver Illness'**
  String get emergencyReasonDriverIllness;

  /// No description provided for @emergencyReasonVehicleBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Breakdown'**
  String get emergencyReasonVehicleBreakdown;

  /// No description provided for @emergencyReasonDriverNoShow.
  ///
  /// In en, this message translates to:
  /// **'Driver No-Show'**
  String get emergencyReasonDriverNoShow;

  /// No description provided for @emergencyReasonAccident.
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get emergencyReasonAccident;

  /// No description provided for @emergencyReasonPersonalEmergency.
  ///
  /// In en, this message translates to:
  /// **'Personal Emergency'**
  String get emergencyReasonPersonalEmergency;

  /// No description provided for @emergencyReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get emergencyReasonOther;

  /// No description provided for @preferredDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'Preferred'**
  String get preferredDriverLabel;

  /// No description provided for @emergencyRideLabel.
  ///
  /// In en, this message translates to:
  /// **'Ride: {id}'**
  String emergencyRideLabel(String id);

  /// No description provided for @emergencyOriginalDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'Original driver: {id}'**
  String emergencyOriginalDriverLabel(String id);

  /// No description provided for @emergencyNewDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'New driver: {id}'**
  String emergencyNewDriverLabel(String id);

  /// No description provided for @ridePoolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride Pools'**
  String get ridePoolsTitle;

  /// No description provided for @createRidePoolDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Ride Pool'**
  String get createRidePoolDialogTitle;

  /// No description provided for @poolNameOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Pool Name (optional)'**
  String get poolNameOptionalLabel;

  /// No description provided for @poolNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Airport Morning Shuttle'**
  String get poolNameHint;

  /// No description provided for @routeDirectionOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Route Direction (optional)'**
  String get routeDirectionOptionalLabel;

  /// No description provided for @routeDirectionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., City Center → Airport'**
  String get routeDirectionHint;

  /// No description provided for @maxPassengersLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Passengers:'**
  String get maxPassengersLabel;

  /// No description provided for @ridePoolCreated.
  ///
  /// In en, this message translates to:
  /// **'Ride pool created'**
  String get ridePoolCreated;

  /// No description provided for @noRidePools.
  ///
  /// In en, this message translates to:
  /// **'No ride pools'**
  String get noRidePools;

  /// No description provided for @createPoolToCombineRides.
  ///
  /// In en, this message translates to:
  /// **'Create a pool to combine rides'**
  String get createPoolToCombineRides;

  /// No description provided for @errorLoadingPoolDetails.
  ///
  /// In en, this message translates to:
  /// **'Error loading pool details: {error}'**
  String errorLoadingPoolDetails(String error);

  /// No description provided for @poolDetailStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get poolDetailStatusLabel;

  /// No description provided for @poolDetailPassengersLabel.
  ///
  /// In en, this message translates to:
  /// **'Passengers'**
  String get poolDetailPassengersLabel;

  /// No description provided for @poolDetailRouteLabel.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get poolDetailRouteLabel;

  /// No description provided for @poolDetailDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get poolDetailDriverLabel;

  /// No description provided for @poolMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Members:'**
  String get poolMembersLabel;

  /// No description provided for @noRidesInPool.
  ///
  /// In en, this message translates to:
  /// **'No rides in this pool yet'**
  String get noRidesInPool;

  /// No description provided for @companySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Company Settings'**
  String get companySettingsTitle;

  /// No description provided for @navItemCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get navItemCompany;

  /// No description provided for @navItemUsersRoles.
  ///
  /// In en, this message translates to:
  /// **'Users & Roles'**
  String get navItemUsersRoles;

  /// No description provided for @navItemCompliance.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get navItemCompliance;

  /// No description provided for @navItemBillingDatev.
  ///
  /// In en, this message translates to:
  /// **'Billing & DATEV'**
  String get navItemBillingDatev;

  /// No description provided for @navItemGeofences.
  ///
  /// In en, this message translates to:
  /// **'Geofences'**
  String get navItemGeofences;

  /// No description provided for @companyProfileSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Company profile'**
  String get companyProfileSectionTitle;

  /// No description provided for @companyProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Legal entity information displayed on invoices and reports.'**
  String get companyProfileSubtitle;

  /// No description provided for @complianceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Compliance & Security'**
  String get complianceSectionTitle;

  /// No description provided for @complianceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Data privacy, access management, and audit controls.'**
  String get complianceSubtitle;

  /// No description provided for @billingDatevSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing & DATEV'**
  String get billingDatevSectionTitle;

  /// No description provided for @billingDatevSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tariff configuration and DATEV export settings.'**
  String get billingDatevSubtitle;

  /// No description provided for @tariffSettingsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Tariff Settings'**
  String get tariffSettingsSectionTitle;

  /// No description provided for @datevIntegrationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'DATEV Integration'**
  String get datevIntegrationSectionTitle;

  /// No description provided for @datevIntegrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Beraternummer und Mandantennummer werden im EXTF-Buchungsstapel-Header verwendet.'**
  String get datevIntegrationSubtitle;

  /// No description provided for @legalNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Legal name'**
  String get legalNameLabel;

  /// No description provided for @vatIdLabel.
  ///
  /// In en, this message translates to:
  /// **'VAT ID'**
  String get vatIdLabel;

  /// No description provided for @defaultCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Default currency'**
  String get defaultCurrencyLabel;

  /// No description provided for @timezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezoneLabel;

  /// No description provided for @commissionRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Commission Rate (%)'**
  String get commissionRateLabel;

  /// No description provided for @cancellationFeeSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Fee (€)'**
  String get cancellationFeeSettingsLabel;

  /// No description provided for @noShowFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'No-Show Fee (€)'**
  String get noShowFeeLabel;

  /// No description provided for @basePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Base Price (€)'**
  String get basePriceLabel;

  /// No description provided for @pricePerKmLabel.
  ///
  /// In en, this message translates to:
  /// **'Price per Km (€)'**
  String get pricePerKmLabel;

  /// No description provided for @airportSurchargeLabel.
  ///
  /// In en, this message translates to:
  /// **'Airport Surcharge (€)'**
  String get airportSurchargeLabel;

  /// No description provided for @nightSurchargeLabel.
  ///
  /// In en, this message translates to:
  /// **'Night Surcharge (€)'**
  String get nightSurchargeLabel;

  /// No description provided for @workStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Work Start'**
  String get workStartLabel;

  /// No description provided for @workEndLabel.
  ///
  /// In en, this message translates to:
  /// **'Work End'**
  String get workEndLabel;

  /// No description provided for @settingsSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get settingsSavedSuccess;

  /// No description provided for @failedToSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSaveSettings(String error);

  /// No description provided for @gdprExportTitle.
  ///
  /// In en, this message translates to:
  /// **'GDPR export'**
  String get gdprExportTitle;

  /// No description provided for @gdprExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download all personal data'**
  String get gdprExportSubtitle;

  /// No description provided for @auditLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get auditLogTitle;

  /// No description provided for @auditLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review system activity'**
  String get auditLogSubtitle;

  /// No description provided for @activeSessionsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get activeSessionsCardTitle;

  /// No description provided for @activeSessionsCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage logged-in devices'**
  String get activeSessionsCardSubtitle;

  /// No description provided for @blacklistCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Blacklist'**
  String get blacklistCardTitle;

  /// No description provided for @blacklistCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage blocked accounts'**
  String get blacklistCardSubtitle;

  /// No description provided for @comingSoonLabel.
  ///
  /// In en, this message translates to:
  /// **'{label} coming soon'**
  String comingSoonLabel(String label);

  /// No description provided for @settingsCompanyProfile.
  ///
  /// In en, this message translates to:
  /// **'Company Profile'**
  String get settingsCompanyProfile;

  /// No description provided for @generalSettingsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettingsSectionTitle;

  /// No description provided for @gdprScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data (GDPR)'**
  String get gdprScreenTitle;

  /// No description provided for @consentManagementSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Consent Management'**
  String get consentManagementSectionTitle;

  /// No description provided for @consentDataProcessingLabel.
  ///
  /// In en, this message translates to:
  /// **'Data Processing'**
  String get consentDataProcessingLabel;

  /// No description provided for @consentDataProcessingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow processing of ride and account data'**
  String get consentDataProcessingSubtitle;

  /// No description provided for @consentMarketingLabel.
  ///
  /// In en, this message translates to:
  /// **'Marketing'**
  String get consentMarketingLabel;

  /// No description provided for @consentMarketingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive promotional emails and offers'**
  String get consentMarketingSubtitle;

  /// No description provided for @consentAnalyticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get consentAnalyticsLabel;

  /// No description provided for @consentAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app with usage analytics'**
  String get consentAnalyticsSubtitle;

  /// No description provided for @consentThirdPartySharingLabel.
  ///
  /// In en, this message translates to:
  /// **'Third-Party Sharing'**
  String get consentThirdPartySharingLabel;

  /// No description provided for @consentThirdPartySharingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share data with partner services'**
  String get consentThirdPartySharingSubtitle;

  /// No description provided for @yourDataSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Data'**
  String get yourDataSectionTitle;

  /// No description provided for @exportMyDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get exportMyDataLabel;

  /// No description provided for @exportMyDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download all personal data we have stored about you'**
  String get exportMyDataSubtitle;

  /// No description provided for @dataDeletionSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Deletion'**
  String get dataDeletionSectionTitle;

  /// No description provided for @requestDataDeletionLabel.
  ///
  /// In en, this message translates to:
  /// **'Request Data Deletion'**
  String get requestDataDeletionLabel;

  /// No description provided for @requestDataDeletionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all your data and account'**
  String get requestDataDeletionSubtitle;

  /// No description provided for @pendingDeletionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A deletion request is already pending'**
  String get pendingDeletionSubtitle;

  /// No description provided for @pendingChipLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingChipLabel;

  /// No description provided for @requestHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Request History'**
  String get requestHistoryTitle;

  /// No description provided for @requestDeletionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Data Deletion'**
  String get requestDeletionDialogTitle;

  /// No description provided for @requestDeletionDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will submit a request to delete all your personal data. This action cannot be undone. Your account will be deactivated once the request is processed.\n\nAre you sure you want to proceed?'**
  String get requestDeletionDialogContent;

  /// No description provided for @requestDeletionButton.
  ///
  /// In en, this message translates to:
  /// **'Request Deletion'**
  String get requestDeletionButton;

  /// No description provided for @dataExportCopied.
  ///
  /// In en, this message translates to:
  /// **'Data export copied to clipboard'**
  String get dataExportCopied;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @deletionRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Deletion request submitted'**
  String get deletionRequestSubmitted;

  /// No description provided for @failedToLoadGdprData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load GDPR data ({consentsCode}/{requestsCode})'**
  String failedToLoadGdprData(String consentsCode, String requestsCode);

  /// No description provided for @dataDeletionRequestType.
  ///
  /// In en, this message translates to:
  /// **'Data Deletion'**
  String get dataDeletionRequestType;

  /// No description provided for @dataExportRequestType.
  ///
  /// In en, this message translates to:
  /// **'Data Export'**
  String get dataExportRequestType;

  /// No description provided for @paymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsTitle;

  /// No description provided for @unpaidBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaidBadgeLabel;

  /// No description provided for @allRidesPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'All rides are paid'**
  String get allRidesPaidLabel;

  /// No description provided for @markAsPaidDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as Paid'**
  String get markAsPaidDialogTitle;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Method:'**
  String get paymentMethodLabel;

  /// No description provided for @paymentMethodSelectLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethodSelectLabel;

  /// No description provided for @paymentMethodPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentMethodPayment;

  /// No description provided for @paymentMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// No description provided for @paymentMethodCard.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get paymentMethodCard;

  /// No description provided for @paymentMethodInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get paymentMethodInvoice;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount: {amount} EUR'**
  String amountLabel(String amount);

  /// No description provided for @confirmPaymentButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get confirmPaymentButton;

  /// No description provided for @paymentRecordedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get paymentRecordedSuccess;

  /// No description provided for @failedToLoadUnpaidRides.
  ///
  /// In en, this message translates to:
  /// **'Failed to load unpaid rides'**
  String get failedToLoadUnpaidRides;

  /// No description provided for @myRideTitle.
  ///
  /// In en, this message translates to:
  /// **'My Ride · {dateTime}'**
  String myRideTitle(String dateTime);

  /// No description provided for @rideTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride · {client}'**
  String rideTitle(String client);

  /// No description provided for @confirmationSentLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirmation sent'**
  String get confirmationSentLabel;

  /// No description provided for @cancellationDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Details'**
  String get cancellationDetailsTitle;

  /// No description provided for @cancellationReasonDetail.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String cancellationReasonDetail(String reason);

  /// No description provided for @cancelledByLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by: {name}'**
  String cancelledByLabel(String name);

  /// No description provided for @cancellationFeeDisplay.
  ///
  /// In en, this message translates to:
  /// **'Fee: €{fee}'**
  String cancellationFeeDisplay(String fee);

  /// No description provided for @ratingTitle.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get ratingTitle;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// No description provided for @openChatButton.
  ///
  /// In en, this message translates to:
  /// **'Open Chat'**
  String get openChatButton;

  /// No description provided for @rideStatusUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ride status updated successfully'**
  String get rideStatusUpdatedSuccess;

  /// No description provided for @failedToUpdateRideStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to update ride status: {error}'**
  String failedToUpdateRideStatus(String error);

  /// No description provided for @driverAssignedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Driver assigned successfully'**
  String get driverAssignedSuccess;

  /// No description provided for @failedToAssignDriver.
  ///
  /// In en, this message translates to:
  /// **'Failed to assign driver: {error}'**
  String failedToAssignDriver(String error);

  /// No description provided for @rideCancelledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ride cancelled'**
  String get rideCancelledSuccess;

  /// No description provided for @completeRideDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Ride'**
  String get completeRideDialogTitle;

  /// No description provided for @completeRideDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Mark this ride as completed?'**
  String get completeRideDialogContent;

  /// No description provided for @createNewRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Ride'**
  String get createNewRideTitle;

  /// No description provided for @rideCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ride created successfully!'**
  String get rideCreatedSuccess;

  /// No description provided for @conflictDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule conflict'**
  String get conflictDialogTitle;

  /// No description provided for @conflictDialogContent.
  ///
  /// In en, this message translates to:
  /// **'{message}\n\nThe ride was created and is in the dispatcher pool. Assign it to yourself anyway?'**
  String conflictDialogContent(String message);

  /// No description provided for @conflictDialogContentDefault.
  ///
  /// In en, this message translates to:
  /// **'You already have a ride around this time. The ride was created and is in the dispatcher pool. Assign it to yourself anyway?'**
  String get conflictDialogContentDefault;

  /// No description provided for @conflictDialogContentRich.
  ///
  /// In en, this message translates to:
  /// **'The driver is already booked: {from} → {to} at {time}.\n\nThe ride was created and is in the dispatcher pool. Assign it anyway?'**
  String conflictDialogContentRich(String from, String to, String time);

  /// No description provided for @keepInPoolButton.
  ///
  /// In en, this message translates to:
  /// **'Keep in pool'**
  String get keepInPoolButton;

  /// No description provided for @assignAnywayButton.
  ///
  /// In en, this message translates to:
  /// **'Assign anyway'**
  String get assignAnywayButton;

  /// No description provided for @exportRidesTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Rides'**
  String get exportRidesTitle;

  /// No description provided for @copyCsvButton.
  ///
  /// In en, this message translates to:
  /// **'Copy CSV'**
  String get copyCsvButton;

  /// No description provided for @dateRangeButton.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRangeButton;

  /// No description provided for @noRidesMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No rides match the filters'**
  String get noRidesMatchFilters;

  /// No description provided for @exportSummaryTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get exportSummaryTotal;

  /// No description provided for @exportSummaryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get exportSummaryCompleted;

  /// No description provided for @exportSummaryRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get exportSummaryRevenue;

  /// No description provided for @csvCopiedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'CSV data copied to clipboard ({count} rides)'**
  String csvCopiedSnackbar(int count);

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @flightsMunichAirportTitle.
  ///
  /// In en, this message translates to:
  /// **'Flights · Munich Airport'**
  String get flightsMunichAirportTitle;

  /// No description provided for @autoSyncedLabel.
  ///
  /// In en, this message translates to:
  /// **'auto-synced'**
  String get autoSyncedLabel;

  /// No description provided for @arrivalsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Arrivals'**
  String get arrivalsTabLabel;

  /// No description provided for @arrivalsBoardTitle.
  ///
  /// In en, this message translates to:
  /// **'Arrivals · Munich Airport'**
  String get arrivalsBoardTitle;

  /// No description provided for @departuresTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Departures'**
  String get departuresTabLabel;

  /// No description provided for @noArrivalsFound.
  ///
  /// In en, this message translates to:
  /// **'No arrivals found'**
  String get noArrivalsFound;

  /// No description provided for @noDeparturesFound.
  ///
  /// In en, this message translates to:
  /// **'No departures found'**
  String get noDeparturesFound;

  /// No description provided for @flightDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Flight details'**
  String get flightDetailsTitle;

  /// No description provided for @gateNotPublished.
  ///
  /// In en, this message translates to:
  /// **'Gate not published yet'**
  String get gateNotPublished;

  /// No description provided for @trackFlightLive.
  ///
  /// In en, this message translates to:
  /// **'Track live on Flightradar24'**
  String get trackFlightLive;

  /// No description provided for @couldNotOpenFlightTracker.
  ///
  /// In en, this message translates to:
  /// **'Could not open the flight tracker'**
  String get couldNotOpenFlightTracker;

  /// No description provided for @errorLoadingFlights.
  ///
  /// In en, this message translates to:
  /// **'Error loading flights: {error}'**
  String errorLoadingFlights(String error);

  /// No description provided for @flightColumnFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get flightColumnFlight;

  /// No description provided for @flightColumnOriginDest.
  ///
  /// In en, this message translates to:
  /// **'Origin / Dest.'**
  String get flightColumnOriginDest;

  /// No description provided for @flightColumnSched.
  ///
  /// In en, this message translates to:
  /// **'Sched.'**
  String get flightColumnSched;

  /// No description provided for @flightColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get flightColumnStatus;

  /// No description provided for @flightColumnLinkedRide.
  ///
  /// In en, this message translates to:
  /// **'Linked ride'**
  String get flightColumnLinkedRide;

  /// No description provided for @flightStatusOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get flightStatusOnTime;

  /// No description provided for @flightStatusDelayed.
  ///
  /// In en, this message translates to:
  /// **'Delayed'**
  String get flightStatusDelayed;

  /// No description provided for @flightStatusBoarding.
  ///
  /// In en, this message translates to:
  /// **'Boarding'**
  String get flightStatusBoarding;

  /// No description provided for @flightStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get flightStatusCancelled;

  /// No description provided for @flightStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get flightStatusUnknown;

  /// No description provided for @flightStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get flightStatusScheduled;

  /// No description provided for @flightStatusDeparted.
  ///
  /// In en, this message translates to:
  /// **'Departed'**
  String get flightStatusDeparted;

  /// No description provided for @flightStatusEnRoute.
  ///
  /// In en, this message translates to:
  /// **'En route'**
  String get flightStatusEnRoute;

  /// No description provided for @flightStatusLanded.
  ///
  /// In en, this message translates to:
  /// **'Landed'**
  String get flightStatusLanded;

  /// No description provided for @flightStatusDiverted.
  ///
  /// In en, this message translates to:
  /// **'Diverted'**
  String get flightStatusDiverted;

  /// Header of the flight details card on the ride details screen
  ///
  /// In en, this message translates to:
  /// **'Flight Information'**
  String get flightInformation;

  /// Label for the flight number field on the ride flight card
  ///
  /// In en, this message translates to:
  /// **'Flight Number'**
  String get flightNumber;

  /// Label for an arriving flight's time on the ride flight card
  ///
  /// In en, this message translates to:
  /// **'Arrival Time'**
  String get arrivalTime;

  /// Label for a departing flight's time on the ride flight card
  ///
  /// In en, this message translates to:
  /// **'Departure Time'**
  String get departureTime;

  /// No description provided for @flightNotLinked.
  ///
  /// In en, this message translates to:
  /// **'— not linked'**
  String get flightNotLinked;

  /// No description provided for @whoCanSeeWhomTitle.
  ///
  /// In en, this message translates to:
  /// **'Who can see whom'**
  String get whoCanSeeWhomTitle;

  /// No description provided for @visibleToAllDispatchers.
  ///
  /// In en, this message translates to:
  /// **'Visible to all dispatchers'**
  String get visibleToAllDispatchers;

  /// No description provided for @scheduleHiddenFromOthers.
  ///
  /// In en, this message translates to:
  /// **'Schedule hidden from others'**
  String get scheduleHiddenFromOthers;

  /// No description provided for @noDriversInCompany.
  ///
  /// In en, this message translates to:
  /// **'No drivers in your company.'**
  String get noDriversInCompany;

  /// No description provided for @failedToUpdateVisibilityError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update visibility: {error}'**
  String failedToUpdateVisibilityError(String error);

  /// No description provided for @auditLogScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit Log'**
  String get auditLogScreenTitle;

  /// No description provided for @searchByEntityIdHint.
  ///
  /// In en, this message translates to:
  /// **'Search by entity ID...'**
  String get searchByEntityIdHint;

  /// No description provided for @noAuditEntriesFound.
  ///
  /// In en, this message translates to:
  /// **'No audit entries found'**
  String get noAuditEntriesFound;

  /// No description provided for @onlineOnRideLabel.
  ///
  /// In en, this message translates to:
  /// **'Online · ride at {dateTime}'**
  String onlineOnRideLabel(String dateTime);

  /// No description provided for @startConversationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation with the driver'**
  String get startConversationSubtitle;

  /// No description provided for @failedToSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to send: {error}'**
  String failedToSendMessage(String error);

  /// No description provided for @totalRidesStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Rides'**
  String get totalRidesStatLabel;

  /// No description provided for @onTimeStatLabel.
  ///
  /// In en, this message translates to:
  /// **'On-time'**
  String get onTimeStatLabel;

  /// No description provided for @completionRateStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Completion rate'**
  String get completionRateStatLabel;

  /// No description provided for @avgSlackStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg Slack'**
  String get avgSlackStatLabel;

  /// No description provided for @gmvStatLabel.
  ///
  /// In en, this message translates to:
  /// **'GMV'**
  String get gmvStatLabel;

  /// No description provided for @ridesByTenantTitle.
  ///
  /// In en, this message translates to:
  /// **'Rides by Tenant'**
  String get ridesByTenantTitle;

  /// No description provided for @rideStatusBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride Status Breakdown'**
  String get rideStatusBreakdownTitle;

  /// No description provided for @platformActiveSessionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Platform Active Sessions'**
  String get platformActiveSessionsLabel;

  /// No description provided for @clientPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get clientPaymentTitle;

  /// No description provided for @paymentMethodsSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT METHODS'**
  String get paymentMethodsSectionLabel;

  /// No description provided for @corporateInvoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Corporate invoice'**
  String get corporateInvoiceLabel;

  /// No description provided for @addPaymentMethodButton.
  ///
  /// In en, this message translates to:
  /// **'Add payment method'**
  String get addPaymentMethodButton;

  /// No description provided for @shareRideLink.
  ///
  /// In en, this message translates to:
  /// **'Share tracking link'**
  String get shareRideLink;

  /// No description provided for @trackingLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Tracking link copied to clipboard'**
  String get trackingLinkCopied;

  /// No description provided for @bookWithoutClient.
  ///
  /// In en, this message translates to:
  /// **'Without client (from chat)'**
  String get bookWithoutClient;

  /// No description provided for @fromChatRide.
  ///
  /// In en, this message translates to:
  /// **'From chat'**
  String get fromChatRide;

  /// No description provided for @linkClient.
  ///
  /// In en, this message translates to:
  /// **'Add client details'**
  String get linkClient;

  /// No description provided for @calendarSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar Sharing'**
  String get calendarSharingTitle;

  /// No description provided for @calendarSharingMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Calendar Sharing'**
  String get calendarSharingMenuItem;

  /// No description provided for @shareInvitesSection.
  ///
  /// In en, this message translates to:
  /// **'My invite codes'**
  String get shareInvitesSection;

  /// No description provided for @shareCreateInvite.
  ///
  /// In en, this message translates to:
  /// **'Create invite code'**
  String get shareCreateInvite;

  /// No description provided for @shareInviteExpiry1Day.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get shareInviteExpiry1Day;

  /// No description provided for @shareInviteExpiry7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get shareInviteExpiry7Days;

  /// No description provided for @shareInviteExpiry30Days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get shareInviteExpiry30Days;

  /// No description provided for @shareInviteCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite code created'**
  String get shareInviteCreatedTitle;

  /// No description provided for @shareInviteCreatedHint.
  ///
  /// In en, this message translates to:
  /// **'Send this code to a driver or dispatcher of another company. They enter it in their app under Calendar Sharing.'**
  String get shareInviteCreatedHint;

  /// No description provided for @shareCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get shareCopyCode;

  /// No description provided for @shareCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied to clipboard'**
  String get shareCodeCopied;

  /// No description provided for @shareRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get shareRevoke;

  /// No description provided for @shareGrantedSection.
  ///
  /// In en, this message translates to:
  /// **'Who sees my calendar'**
  String get shareGrantedSection;

  /// No description provided for @shareSharedWithMeSection.
  ///
  /// In en, this message translates to:
  /// **'Shared with me'**
  String get shareSharedWithMeSection;

  /// No description provided for @shareEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get shareEnterCode;

  /// No description provided for @shareRedeemTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a shared calendar'**
  String get shareRedeemTitle;

  /// No description provided for @shareRedeemHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the invite code or link'**
  String get shareRedeemHint;

  /// No description provided for @shareRedeemConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get shareRedeemConnect;

  /// No description provided for @shareRedeemSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String shareRedeemSuccess(String name);

  /// No description provided for @shareUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get shareUnlink;

  /// No description provided for @shareNoInvites.
  ///
  /// In en, this message translates to:
  /// **'No active invite codes'**
  String get shareNoInvites;

  /// No description provided for @shareNoGrants.
  ///
  /// In en, this message translates to:
  /// **'You have not shared your calendar with anyone'**
  String get shareNoGrants;

  /// No description provided for @shareNoSharedWithMe.
  ///
  /// In en, this message translates to:
  /// **'No calendars have been shared with you'**
  String get shareNoSharedWithMe;

  /// No description provided for @shareValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String shareValidUntil(String date);

  /// No description provided for @shareSince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String shareSince(String date);

  /// No description provided for @shareActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String shareActionFailed(String error);

  /// No description provided for @sharedCalendarAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get sharedCalendarAvailable;

  /// No description provided for @sharedCalendarBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get sharedCalendarBusy;

  /// No description provided for @sharedCalendarShift.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get sharedCalendarShift;

  /// No description provided for @sharedCalendarEmptyDay.
  ///
  /// In en, this message translates to:
  /// **'No shifts or busy slots'**
  String get sharedCalendarEmptyDay;

  /// No description provided for @sharedCalendarEmptyWeek.
  ///
  /// In en, this message translates to:
  /// **'No shifts or busy slots this week'**
  String get sharedCalendarEmptyWeek;

  /// No description provided for @sharedCalendarTimesHint.
  ///
  /// In en, this message translates to:
  /// **'Shift times as provided by {company}'**
  String sharedCalendarTimesHint(String company);

  /// No description provided for @sharedWithMeGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Shared with me'**
  String get sharedWithMeGroupLabel;

  /// No description provided for @myCompanyGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'My company'**
  String get myCompanyGroupLabel;

  /// No description provided for @addShiftTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add shift'**
  String get addShiftTooltip;

  /// No description provided for @addShiftTitle.
  ///
  /// In en, this message translates to:
  /// **'New shift'**
  String get addShiftTitle;

  /// No description provided for @shiftDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get shiftDateLabel;

  /// No description provided for @shiftStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get shiftStartLabel;

  /// No description provided for @shiftEndLabel.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get shiftEndLabel;

  /// No description provided for @shiftRepeatUntilLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat daily until (optional)'**
  String get shiftRepeatUntilLabel;

  /// No description provided for @shiftNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get shiftNoteLabel;

  /// No description provided for @shiftCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get shiftCreateButton;

  /// No description provided for @shiftsCreatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Shifts created: {count}'**
  String shiftsCreatedSnack(int count);

  /// No description provided for @shiftOverlapSnack.
  ///
  /// In en, this message translates to:
  /// **'The selected time overlaps an existing shift. Multiple shifts per day are allowed — pick a time that doesn\'t overlap.'**
  String get shiftOverlapSnack;

  /// No description provided for @shiftTimeOrderError.
  ///
  /// In en, this message translates to:
  /// **'Start time must be before end time'**
  String get shiftTimeOrderError;

  /// No description provided for @shiftCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this shift?'**
  String get shiftCancelTitle;

  /// No description provided for @shiftCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel shift'**
  String get shiftCancelButton;

  /// No description provided for @shiftCancelledSnack.
  ///
  /// In en, this message translates to:
  /// **'Shift cancelled'**
  String get shiftCancelledSnack;

  /// No description provided for @shiftsStripLabel.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get shiftsStripLabel;

  /// No description provided for @noShiftsForDay.
  ///
  /// In en, this message translates to:
  /// **'No shifts'**
  String get noShiftsForDay;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
