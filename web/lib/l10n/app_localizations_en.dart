// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Dispax';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get invalidCredentials => 'Invalid email or password';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get all => 'All';

  @override
  String get myRides => 'My Rides';

  @override
  String get history => 'History';

  @override
  String get map => 'Map';

  @override
  String get flights => 'Flights';

  @override
  String get profile => 'Profile';

  @override
  String get calendar => 'Calendar';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get settings => 'Settings';

  @override
  String get pendingRides => 'Pending Rides';

  @override
  String ridesAwaiting(int count) {
    return '$count ride(s) awaiting assignment';
  }

  @override
  String get driverSchedules => 'Driver Schedules';

  @override
  String get noDriversScheduled => 'No drivers scheduled';

  @override
  String get noPendingRides => 'No pending rides';

  @override
  String get allRidesAssigned => 'All rides have been assigned';

  @override
  String get selectDriver => 'Select Driver';

  @override
  String get reassignRide => 'Reassign Ride';

  @override
  String get confirmReassignment => 'Confirm Reassignment';

  @override
  String get reassign => 'Reassign';

  @override
  String get assign => 'Assign';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get searchClientAddress => 'Search client, address...';

  @override
  String get searchDriverName => 'Search driver name...';

  @override
  String get airport => 'Airport';

  @override
  String get available => 'Available';

  @override
  String get moderate => 'Moderate';

  @override
  String get busy => 'Busy';

  @override
  String get sortTimeEarliest => 'Time (earliest first)';

  @override
  String get sortTimeLatest => 'Time (latest first)';

  @override
  String get sortClientName => 'Client name';

  @override
  String nRidesAssigned(int count) {
    return '$count ride(s) assigned';
  }

  @override
  String timeConflicts(int count) {
    return '$count time conflict(s)';
  }

  @override
  String get dropHereToAssign => 'Drop here to assign';

  @override
  String get todaysHistory => 'Today\'s History';

  @override
  String get thisWeeksHistory => 'This Week\'s History';

  @override
  String get thisMonthsHistory => 'This Month\'s History';

  @override
  String get allTimeHistory => 'All Time History';

  @override
  String get rideHistory => 'Ride History';

  @override
  String get myRideHistory => 'My Ride History';

  @override
  String get noRideHistory => 'No Ride History';

  @override
  String get completedRidesAppearHere =>
      'Your completed rides will appear here';

  @override
  String get noRidesForPeriod => 'No rides for this period';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get earned => 'Earned';

  @override
  String get spent => 'Spent';

  @override
  String get analytics => 'Analytics';

  @override
  String get totalRides => 'Total Rides';

  @override
  String get completedRides => 'Completed';

  @override
  String get cancelledRides => 'Cancelled';

  @override
  String get inProgressRides => 'In Progress';

  @override
  String get requestedRides => 'Requested';

  @override
  String get assignedRides => 'Assigned';

  @override
  String get activeDrivers => 'Active Drivers';

  @override
  String get totalClients => 'Total Clients';

  @override
  String get todayRevenue => 'Today Revenue';

  @override
  String get monthlyRevenue => 'Monthly Revenue';

  @override
  String get avgAssignmentTime => 'Avg. Assignment';

  @override
  String get cancellationRate => 'Cancellation %';

  @override
  String get driverLoad => 'Driver Load';

  @override
  String get dailyOverview => 'Daily Overview';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get send => 'Send';

  @override
  String get chatUnavailable => 'Chat is available only during active rides';

  @override
  String get noMessages => 'No messages yet';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get accountSettings => 'Account';

  @override
  String get changePassword => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get passwordChanged => 'Password changed successfully';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get rideUpdates => 'Ride Updates';

  @override
  String get chatMessages => 'Chat Messages';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get systemTheme => 'System';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get german => 'Deutsch';

  @override
  String get ukrainian => 'Ukrainian';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get name => 'Name';

  @override
  String get phone => 'Phone';

  @override
  String get profileUpdated => 'Profile updated successfully';

  @override
  String get security => 'Security';

  @override
  String get biometricLogin => 'Biometric Login';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get superAdminDashboard => 'Platform Admin';

  @override
  String get companies => 'Companies';

  @override
  String get companiesList => 'Companies List';

  @override
  String get platformAnalytics => 'Platform Analytics';

  @override
  String get platformRevenue => 'Platform Revenue';

  @override
  String get activeConnections => 'Active Connections';

  @override
  String get companyStatus => 'Company Status';

  @override
  String get subscriptionPlan => 'Subscription Plan';

  @override
  String get billingAnalytics => 'Billing Analytics';

  @override
  String get connectionAnalytics => 'Connection Analytics';

  @override
  String get superAdminSettings => 'Platform Settings';

  @override
  String get addCompany => 'Add Company';

  @override
  String get editCompany => 'Edit Company';

  @override
  String get deleteCompany => 'Deactivate Company';

  @override
  String get deactivateCompanyConfirm =>
      'Are you sure you want to deactivate this company? The company will be marked as Inactive but all data will be preserved.';

  @override
  String get companyName => 'Company Name';

  @override
  String get companyEmail => 'Company Email';

  @override
  String get companyPhone => 'Company Phone';

  @override
  String get companyAddress => 'Company Address';

  @override
  String get checkpointLanded => 'Landed';

  @override
  String get checkpointArrivalsHall => 'Arrivals Hall';

  @override
  String get checkpointTerminalExit => 'Terminal Exit';

  @override
  String get markCheckpointButton => 'I\'m here';

  @override
  String get airportCheckpointPanelTitle => 'My location in terminal';

  @override
  String checkpointNotifTitle(String checkpoint) {
    return 'Client reached $checkpoint';
  }

  @override
  String checkpointNotifBody(String checkpointName) {
    return 'Your client is at $checkpointName.';
  }
}
