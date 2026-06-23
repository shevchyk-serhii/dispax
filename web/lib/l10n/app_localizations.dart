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
  /// **'Assign Ride #{rideId}'**
  String assignRideDialogTitle(String rideId);

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
  /// **'Reassign ride #{rideId}'**
  String reassignRideDialogTitle(String rideId);

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
