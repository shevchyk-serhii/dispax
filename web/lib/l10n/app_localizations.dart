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

  /// No description provided for @noPendingRides.
  ///
  /// In en, this message translates to:
  /// **'No pending rides'**
  String get noPendingRides;

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

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

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
