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
  String get selectDriverToViewSchedule =>
      'Select a driver to view their schedule';

  @override
  String get noScheduleForDriver => 'No schedule entries for this driver';

  @override
  String get noPendingRides => 'No pending rides';

  @override
  String get rideAlreadyAssignedInfo =>
      'This ride was already assigned. The list has been refreshed.';

  @override
  String get allRidesAssigned => 'All rides have been assigned';

  @override
  String get selectDriver => 'Select Driver';

  @override
  String get reassignDriver => 'Reassign Driver';

  @override
  String get noDriversFound => 'No drivers found';

  @override
  String get reassignRide => 'Reassign Ride';

  @override
  String get confirmReassignment => 'Confirm Reassignment';

  @override
  String get reassign => 'Reassign';

  @override
  String get assign => 'Assign';

  @override
  String get driverDashboardTitle => 'Driver Dashboard';

  @override
  String get secretaryDashboardTitle => 'Secretary Dashboard';

  @override
  String get dispatcherDashboardTitle => 'Dispatcher Dashboard';

  @override
  String get adminDashboardTitle => 'Admin Dashboard';

  @override
  String get platformAdminTitle => 'Platform Admin';

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
  String get passwordPolicyRules =>
      'Password must be at least 8 characters with an uppercase letter, a lowercase letter, and a digit';

  @override
  String get forcePasswordChangeTitle => 'Set a new password';

  @override
  String get forcePasswordChangeMessage =>
      'Your account uses a temporary password. Please set a new password to continue.';

  @override
  String get updateRequired => 'Update required';

  @override
  String get updateRequiredMessage =>
      'This version of the app is no longer supported. Please update to the latest version to continue.';

  @override
  String get updateNow => 'Update now';

  @override
  String get temporaryPassword => 'Temporary password';

  @override
  String get temporaryPasswordHint =>
      'The user will be asked to change it on first login.';

  @override
  String get tempPasswordRules =>
      'At least 8 characters with an uppercase letter, a lowercase letter, and a digit';

  @override
  String get setNewPassword => 'Set new password';

  @override
  String get userCreatedSharePassword =>
      'User created. Share the temporary password with them.';

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
  String get uploadPhoto => 'Upload Photo';

  @override
  String get changePhoto => 'Change Photo';

  @override
  String get removePhoto => 'Remove Photo';

  @override
  String get photoUploadedSuccessfully => 'Photo uploaded successfully';

  @override
  String get failedToUploadPhoto => 'Failed to upload photo';

  @override
  String get security => 'Security';

  @override
  String get biometricLogin => 'Biometric Login';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get appVersion => 'App version';

  @override
  String get backendVersion => 'Backend version';

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
  String passengerCheckpointStatus(String checkpoint) {
    return 'Passenger: $checkpoint';
  }

  @override
  String get markCheckpointButton => 'I\'m here';

  @override
  String get airportCheckpointPanelTitle => 'My location in terminal';

  @override
  String get airportEntryTitle => 'Airport Entry Time';

  @override
  String get airportDepartIn => 'Depart in:';

  @override
  String get airportEntryLabel => 'Airport entry:';

  @override
  String airportEntryAt(String time) {
    return 'Entry at $time';
  }

  @override
  String airportLandingAt(String time) {
    return 'Landing at $time';
  }

  @override
  String airportLandedAt(String time) {
    return 'Landed at $time';
  }

  @override
  String airportFlightDelay(int minutes) {
    return '+$minutes min delay';
  }

  @override
  String airportScheduledVsActual(String scheduled, String actual) {
    return 'Scheduled $scheduled → $actual';
  }

  @override
  String get airportTravelTime => 'Travel time:';

  @override
  String airportParkingSavings(String amount) {
    return 'Parking savings: $amount';
  }

  @override
  String get airportDepartNow => 'Depart now!';

  @override
  String get airportFlightDelayed => 'Flight delayed. Entry time recalculated.';

  @override
  String airportTimingError(String error) {
    return 'Error loading data: $error';
  }

  @override
  String get airportLoadingTiming => 'Loading entry time data...';

  @override
  String checkpointNotifTitle(String checkpoint) {
    return 'Client reached $checkpoint';
  }

  @override
  String checkpointNotifBody(String checkpointName) {
    return 'Your client is at $checkpointName.';
  }

  @override
  String get airportExits => 'Airport Exits';

  @override
  String get addAirport => 'Add Airport';

  @override
  String get editAirport => 'Edit Airport';

  @override
  String get deleteAirport => 'Deactivate Airport';

  @override
  String get airportCode => 'Airport Code (e.g. MUC)';

  @override
  String get airportName => 'Airport Name';

  @override
  String get addZone => 'Add Zone';

  @override
  String get editZone => 'Edit Zone';

  @override
  String get deleteZone => 'Delete Zone';

  @override
  String get terminalCode => 'Terminal (T1, T2, …)';

  @override
  String get checkpointType => 'Checkpoint Type';

  @override
  String get displayName => 'Display Name';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get radiusMeters => 'Radius (meters)';

  @override
  String get landingGeofence => 'Landing Geofence';

  @override
  String get pickOnMap => 'Pick on map';

  @override
  String get scheduleVisibility => 'Schedule Visibility';

  @override
  String get allowViewOtherSchedules => 'Allow viewing colleagues\' schedules';

  @override
  String viewingDriverSchedule(String driverName) {
    return 'Viewing: $driverName';
  }

  @override
  String get flightDepartureTime => 'Flight departure time';

  @override
  String get manualPickupTimeOptional =>
      'Pickup time (optional — computed if blank)';

  @override
  String confirmedPickupTime(String time) {
    return 'Confirmed pickup: $time';
  }

  @override
  String get pickupTimeComputedAuto =>
      'Computed automatically based on flight departure';

  @override
  String get addressNotFound =>
      'Address could not be located — double-check the spelling.';

  @override
  String addressOutOfServiceArea(int distanceKm, int radiusKm) {
    return 'Address is outside the service area (about $distanceKm km from Munich, max $radiusKm km).';
  }

  @override
  String addressOutOfServiceAreaShort(int radiusKm) {
    return 'Address is outside the service area (max $radiusKm km from Munich).';
  }

  @override
  String get markUnavailable => 'Mark Unavailable';

  @override
  String get driverUnavailable => 'Driver Unavailable';

  @override
  String get unavailabilityReason => 'Reason';

  @override
  String get unavailabilityNote => 'Note (optional)';

  @override
  String get unavailabilityFrom => 'From';

  @override
  String get unavailabilityTo => 'To';

  @override
  String get unavailabilityReasonLunch => 'Lunch';

  @override
  String get unavailabilityReasonVacation => 'Vacation';

  @override
  String get unavailabilityReasonPersonal => 'Personal';

  @override
  String get driverHasScheduleConflict => 'Driver is busy during this time';

  @override
  String get assignAnywayTitle => 'Driver Busy';

  @override
  String assignAnywayMessage(String reason) {
    return 'This driver has a schedule conflict: $reason. Assign anyway?';
  }

  @override
  String get assignAnyway => 'Assign Anyway';

  @override
  String get unavailabilityCreated => 'Unavailability marked successfully';

  @override
  String get unavailabilityDeleted => 'Unavailability removed';

  @override
  String get noUnavailability => 'No unavailability windows';

  @override
  String get preferences => 'Preferences';

  @override
  String get faceIdUnlock => 'Face ID unlock';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get general => 'General';

  @override
  String get activeSessions => 'Active sessions';

  @override
  String get earnings => 'Earnings';

  @override
  String get myEarnings => 'My Earnings';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyDataGdpr => 'Privacy & Data (GDPR)';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get required => 'Required';

  @override
  String get change => 'Change';

  @override
  String get failedToChangePassword => 'Failed to change password';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in to your dispatch account.';

  @override
  String get signIn => 'Sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get faceId => 'Face ID';

  @override
  String get roleDriver => 'Driver';

  @override
  String get roleClient => 'Client';

  @override
  String get roleSecretary => 'Secretary';

  @override
  String get roleClientSecretary => 'Client Secretary';

  @override
  String get roleDispatcher => 'Dispatcher';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleSuperAdmin => 'Super Admin';

  @override
  String get languageSaveFailed => 'Couldn\'t save language to your account';

  @override
  String get billingScreenTitle => 'Billing';

  @override
  String get invoicesTab => 'Invoices';

  @override
  String get companiesTab => 'Companies';

  @override
  String get billingRidesTab => 'Rides';

  @override
  String invoicesCountSubtitle(String month, int count) {
    return '$month · $count Invoices';
  }

  @override
  String get outstandingInvoices => 'Outstanding';

  @override
  String get paidThisMonth => 'Paid (Month)';

  @override
  String get overdueInvoices => 'Overdue';

  @override
  String get collectionRate => 'Collection Rate';

  @override
  String get exportDatevButton => 'Export DATEV';

  @override
  String get createNewInvoiceButton => '+ New Invoice';

  @override
  String get datevExportOpening => 'Opening DATEV Export...';

  @override
  String get createCompanyFirst => 'Please create a company first.';

  @override
  String get newInvoiceTitle => 'New Invoice';

  @override
  String get companiesLabel => 'Company *';

  @override
  String get createInvoiceButton => 'Create Invoice';

  @override
  String get allInvoicesFilter => 'All';

  @override
  String get draftStatusFilter => 'Draft';

  @override
  String get sentStatusFilter => 'Sent';

  @override
  String get paidStatusFilter => 'Paid';

  @override
  String get invoiceTableHeaderNumber => 'INVOICE';

  @override
  String get invoiceTableHeaderClient => 'CLIENT';

  @override
  String get invoiceTableHeaderAmount => 'AMOUNT';

  @override
  String get overdueStatus => 'Overdue';

  @override
  String get paymentReminderSent => 'Payment reminder sent';

  @override
  String get viewDetailsMenu => 'Details';

  @override
  String get gobdCompliant =>
      'GoBD-compliant — invoices are immutably archived.';

  @override
  String get noCompanies => 'No Companies';

  @override
  String get noInvoices => 'No Invoices';

  @override
  String get editCompanyMenu => 'Edit';

  @override
  String get moreActions => 'More actions';

  @override
  String get deleteCompanyMenu => 'Delete';

  @override
  String get addCompanyTitle => 'Add Company';

  @override
  String get editCompanyTitle => 'Edit Company';

  @override
  String get companyNameLabel => 'Name *';

  @override
  String get companyEmailLabel => 'E-Mail';

  @override
  String get companyPhoneLabel => 'Phone';

  @override
  String get companyAddressLabel => 'Address';

  @override
  String get companyVatIdLabel => 'VAT ID (USt-IdNr.)';

  @override
  String get invoiceLanguageLabel => 'Invoice Language';

  @override
  String get languageStandard => 'Default';

  @override
  String get languageGerman => 'German';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUkrainian => 'Ukrainian';

  @override
  String get addCompanyButton => 'Add';

  @override
  String get deleteCompanyConfirmTitle => 'Delete Company?';

  @override
  String deleteCompanyConfirmMsg(String name) {
    return '$name will be deleted.';
  }

  @override
  String get downloadPdfTooltip => 'Download';

  @override
  String get closeTooltip => 'Close';

  @override
  String get closeButton => 'Close';

  @override
  String pdfPreviewTitle(String number) {
    return 'Preview · $number';
  }

  @override
  String get invoiceLineItems => 'Line Items';

  @override
  String get subtotalLabel => 'Subtotal';

  @override
  String vatLineLabel(String rate) {
    return 'VAT $rate%';
  }

  @override
  String totalLabel(String currency) {
    return 'Total ($currency)';
  }

  @override
  String get autoFillRidesButton => 'Auto-fill rides';

  @override
  String get sendInvoiceButton => 'Send Invoice';

  @override
  String get markAsPaidButton => 'Mark as Paid';

  @override
  String get pdfDownloadSuccess => 'PDF downloaded';

  @override
  String get downloadPdfButton => 'Download PDF';

  @override
  String get previewButton => 'Preview';

  @override
  String reminderBadgeLabel(String date) {
    return 'Reminded $date';
  }

  @override
  String get invoicesRailLabel => 'Invoices';

  @override
  String get clientsRailLabel => 'Clients';

  @override
  String get datevRailLabel => 'DATEV';

  @override
  String genericError(String error) {
    return 'Error: $error';
  }

  @override
  String get errorNetwork =>
      'Couldn\'t reach the server. Please check your internet connection and try again.';

  @override
  String get errorTimeout =>
      'The server took too long to respond. Please try again.';

  @override
  String get errorServer =>
      'Something went wrong on our side. Please try again in a moment.';

  @override
  String get errorNotFound => 'We couldn\'t find what you were looking for.';

  @override
  String get errorLoadingData => 'Couldn\'t load the data';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get unbilledRidesTitle => 'Unbilled Rides';

  @override
  String get selectRidesToBill => 'Select rides to bill';

  @override
  String ridesBillingCountSelected(int count) {
    return '$count selected';
  }

  @override
  String ridesBillingCountAvailable(int count) {
    return '$count rides';
  }

  @override
  String get selectCompanyForBilling =>
      'Select a company to see billable rides.';

  @override
  String get noBillableRides => 'No billable rides';

  @override
  String get receiptTooltip => 'Receipt';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String selectedRidesSummary(String subtotal, String total) {
    return 'Selected: $subtotal net · $total total';
  }

  @override
  String get noRidesSelected => 'No rides selected';

  @override
  String get vatPercentLabel => 'VAT %';

  @override
  String get invoiceCreatedTitle => 'Invoice Created';

  @override
  String invoiceCreatedMsg(String number, int count, String amount) {
    return '$number · $count rides · €$amount';
  }

  @override
  String pdfDownloadError(String error) {
    return 'PDF error: $error';
  }

  @override
  String receiptDownloadError(String error) {
    return 'Receipt error: $error';
  }

  @override
  String get datevExportTitle => 'DATEV Export';

  @override
  String noDataForMonth(String monthLabel) {
    return 'No data for $monthLabel';
  }

  @override
  String get revenueSection => 'Revenue';

  @override
  String rowsCountLabel(int count) {
    return '$count rows';
  }

  @override
  String get copyCsvTooltip => 'Copy CSV';

  @override
  String get revenueCsvLabel => 'Revenue CSV';

  @override
  String get expensesSection => 'Expenses';

  @override
  String get expensesCsvLabel => 'Expenses CSV';

  @override
  String get summarySection => 'Summary';

  @override
  String netIncomeResult(String amount) {
    return 'Result: $amount';
  }

  @override
  String get copySummaryCsvTooltip => 'Copy Summary';

  @override
  String get summaryCsvLabel => 'Summary';

  @override
  String copiedToClipboard(String label) {
    return '$label copied to clipboard';
  }

  @override
  String get copyTooltip => 'Copy';

  @override
  String get licensePlate => 'License plate';

  @override
  String get copyAllRevenueHeader => '=== Revenue ===';

  @override
  String get copyAllExpensesHeader => '=== Expenses ===';

  @override
  String get copyAllSummaryHeader => '=== Summary ===';

  @override
  String get allDatevDataLabel => 'All DATEV Data';

  @override
  String downloadFailed(String code) {
    return 'Download failed: $code';
  }

  @override
  String get netIncomeLabel => 'Net Income';

  @override
  String get copyAllButton => 'Copy All';

  @override
  String get downloadCsvExtfButton => 'Download .csv (EXTF)';

  @override
  String get datevExtfFormatInfo =>
      'DATEV Buchungsstapel Format – Import via DATEV Unternehmen Online';

  @override
  String expensesScreenTitle(String monthLabel) {
    return 'Expenses · $monthLabel';
  }

  @override
  String get addExpenseTooltip => 'Record Expense';

  @override
  String get captureExpenseTitle => 'Record Expense';

  @override
  String get expenseCategoryLabel => 'Category';

  @override
  String get expenseAmountLabel => 'Amount (EUR)';

  @override
  String get expenseDescriptionLabel => 'Description (optional)';

  @override
  String get invalidAmountError => 'Please enter a valid amount';

  @override
  String get deleteExpenseConfirmTitle => 'Delete Expense?';

  @override
  String deleteExpenseConfirmMsg(String category, String amount) {
    return '$category · €$amount will be deleted.';
  }

  @override
  String get noExpenses => 'No Expenses';

  @override
  String get noReceiptWarning => 'No Receipt';

  @override
  String get totalExpensesLabel => 'Total';

  @override
  String get newRideAssigned => 'New ride assigned';

  @override
  String get newRideAssignedContent =>
      'You have been assigned a new ride. Do you accept it?';

  @override
  String get decline => 'Decline';

  @override
  String get accept => 'Accept';

  @override
  String get call => 'Call';

  @override
  String get sms => 'SMS';

  @override
  String get completeRideTitle => 'Complete Ride';

  @override
  String get navigate => 'Navigate';

  @override
  String get viewRideOnMap => 'View on map';

  @override
  String get navigateTo => 'Navigate to';

  @override
  String get googleMapsPickup => 'Google Maps — Pickup';

  @override
  String get googleMapsDropoff => 'Google Maps — Drop-off';

  @override
  String get openingNavigation => 'Opening navigation in Google Maps...';

  @override
  String arrivingInMinutes(int etaMinutes) {
    return 'Arriving in $etaMinutes min';
  }

  @override
  String get noCompletedRides => 'No completed rides yet';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshFlightStatus => 'Refresh flight status';

  @override
  String get flightStatusRefreshed => 'Flight status updated';

  @override
  String get flightStatusUnchanged => 'Already up to date';

  @override
  String get flightNotFoundYet => 'Flight not in the system yet';

  @override
  String get failedToRefreshFlightStatus => 'Failed to refresh flight status';

  @override
  String get youreOnline => 'You\'re online';

  @override
  String get youreOffline => 'You\'re offline';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesMessage =>
      'You have unsaved ride details. If you leave, they will be lost.';

  @override
  String get stay => 'Stay';

  @override
  String get discard => 'Discard';

  @override
  String get bookLabel => 'Book';

  @override
  String get monthView => 'Month View';

  @override
  String get weekView => 'Week View';

  @override
  String get dayView => 'Day View';

  @override
  String get board => 'Board';

  @override
  String get goToday => 'Go to Today';

  @override
  String get todaysSchedule => 'Today\'s Schedule';

  @override
  String get noRidesScheduled => 'No rides scheduled';

  @override
  String get enjoyYourFreeDay => 'Enjoy your free day!';

  @override
  String get callClient => 'Call Client';

  @override
  String get startNavigation => 'Start Navigation';

  @override
  String get start => 'Start';

  @override
  String get completeRideButton => 'Complete';

  @override
  String get pickupLocation => 'Pickup location';

  @override
  String get dropoffLocation => 'Drop-off location';

  @override
  String couldNotOpenNavigation(String error) {
    return 'Could not open navigation: $error';
  }

  @override
  String travelTimeMinutes(int minutes) {
    return '$minutes min travel time';
  }

  @override
  String failedToSetPrice(String error) {
    return 'Failed to set price: $error';
  }

  @override
  String get setRidePrice => 'Set ride price';

  @override
  String get setPrice => 'Set price';

  @override
  String get offline => 'Offline';

  @override
  String get acceptingRides => 'You are accepting rides';

  @override
  String get notAcceptingRides => 'You are not accepting rides';

  @override
  String failedToUpdate(String error) {
    return 'Failed to update: $error';
  }

  @override
  String get homeTab => 'Home';

  @override
  String get scheduleTab => 'Schedule';

  @override
  String get calendarTab => 'Calendar';

  @override
  String get newRideTab => 'New Ride';

  @override
  String get moreTab => 'More';

  @override
  String get billingTab => 'Billing';

  @override
  String get moreScreenTitle => 'More';

  @override
  String get moreCategoryInsights => 'Insights';

  @override
  String get moreCategoryOperations => 'Operations';

  @override
  String get moreCategoryFinance => 'Finance';

  @override
  String get moreCategoryAdministration => 'Administration';

  @override
  String get moreCategoryGovernance => 'Governance';

  @override
  String get pickupSignMenuItem => 'Pickup Sign';

  @override
  String get pickupSignTitle => 'Pickup Sign';

  @override
  String get pickupSignHint => 'Enter name or text…';

  @override
  String get pickupSignShowButton => 'Show';

  @override
  String get pickupSignCloseHint => 'Tap or swipe down to close';

  @override
  String get pickupSignAction => 'Pickup sign';

  @override
  String get dispatchBoardTitle => 'Dispatch board';

  @override
  String dispatcherSubtitle(String weekday, String date, int count) {
    return '$weekday, $date · $count active rides';
  }

  @override
  String get searchRidesDrivers => 'Search rides, drivers…';

  @override
  String get newRideButtonLabel => 'New ride';

  @override
  String get activeRidesLabel => 'Active rides';

  @override
  String get atRiskLabel => 'At risk';

  @override
  String get driversOnlineLabel => 'Drivers online';

  @override
  String get onTimeLabel => 'On-time';

  @override
  String get earningsMenuItem => 'Earnings';

  @override
  String get peakHoursMenuItem => 'Peak Hours';

  @override
  String get clientValueMenuItem => 'Client Value';

  @override
  String get driversMenuItem => 'Drivers';

  @override
  String get ratingsMenuItem => 'Ratings';

  @override
  String get auditLogMenuItem => 'Audit Log';

  @override
  String get adminMenuItem => 'Admin';

  @override
  String get companyMenuItem => 'Company';

  @override
  String get expensesMenuItem => 'Expenses';

  @override
  String get exportMenuItem => 'Export';

  @override
  String get templatesMenuItem => 'Templates';

  @override
  String get paymentsMenuItem => 'Payments';

  @override
  String get payrollMenuItem => 'Payroll';

  @override
  String get settingsMenuItem => 'Settings';

  @override
  String get geofencesMenuItem => 'Geofences';

  @override
  String get datevMenuItem => 'DATEV';

  @override
  String get blacklistMenuItem => 'Blacklist';

  @override
  String get emergencyMenuItem => 'Emergency';

  @override
  String get ridePoolsMenuItem => 'Ride Pools';

  @override
  String get notificationsMenuItem => 'Notifications';

  @override
  String get gdprMenuItem => 'GDPR';

  @override
  String get sessionsMenuItem => 'Sessions';

  @override
  String get schedVisibilityMenuItem => 'Sched. Visibility';

  @override
  String get analyticsMenuItem => 'Analytics';

  @override
  String get driverBoardMenuItem => 'Driver Board';

  @override
  String get driverMapMenuItem => 'Driver Map';

  @override
  String assignRideDialogTitle(String client) {
    return 'Assign Ride · $client';
  }

  @override
  String get rideDetailsLabel => 'Ride details';

  @override
  String get clientLabel => 'Client';

  @override
  String get timeLabel => 'Time';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get flightLabel => 'Flight';

  @override
  String get fareLabel => 'Fare';

  @override
  String get assigningToLabel => 'Assigning to';

  @override
  String scheduleConflictsCount(int count) {
    return 'Schedule conflicts ($count)';
  }

  @override
  String get assignDriverButton => 'Assign driver';

  @override
  String reassignRideDialogTitle(String client) {
    return 'Reassign ride · $client';
  }

  @override
  String get nearestAvailableDriversLabel =>
      'NEAREST AVAILABLE DRIVERS · RANKED BY ETA';

  @override
  String get noDriversAvailableForReassignment =>
      'No other drivers available for reassignment.';

  @override
  String reassignNRides(int count) {
    return 'Reassign $count ride(s)';
  }

  @override
  String driverDelayedMessage(String driverName, String slack) {
    return '$driverName is delayed — slack $slack min';
  }

  @override
  String ridesToReassignLabel(int selected, int total) {
    return 'Rides to reassign ($selected/$total)';
  }

  @override
  String get deselectAllButton => 'Deselect all';

  @override
  String get selectAllButton => 'Select all';

  @override
  String get bestMatchBadge => 'Best match';

  @override
  String get stillLateLabel => 'still late';

  @override
  String get slackRestoredLabel => 'slack restored';

  @override
  String get tightLabel => 'tight';

  @override
  String ridesReassignedMessage(int count, String driverName) {
    return '$count ride(s) reassigned to $driverName';
  }

  @override
  String get reassignAnyway => 'Reassign anyway';

  @override
  String get pendingTab => 'Pending';

  @override
  String get assignedTab => 'Assigned';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get noAssignedRides => 'No assigned rides';

  @override
  String get noRidesCurrentlyAssigned =>
      'No rides currently assigned to drivers';

  @override
  String get pendingRequestsHeader => 'Pending requests';

  @override
  String unassignedRidesBadge(int count) {
    return '$count unassigned';
  }

  @override
  String get rideAtRiskTitle => 'Ride at risk of delay';

  @override
  String get etaMonitorBadgeLabel => 'PREDICTIVE ETA MONITOR · 60S';

  @override
  String get viewButton => 'View';

  @override
  String get etaDriverEtaLabel => 'DRIVER ETA';

  @override
  String get etaPickupInLabel => 'PICKUP IN';

  @override
  String get etaSlackLabel => 'SLACK';

  @override
  String get driverEarningsTitle => 'Driver Earnings';

  @override
  String get sortByEarnings => 'Sort by Earnings';

  @override
  String get sortByName => 'Sort by Name';

  @override
  String get sortByRides => 'Sort by Rides';

  @override
  String get driverPayrollTitle => 'Driver Payroll';

  @override
  String get payrollSummaryTitle => 'Payroll Summary';

  @override
  String get loadPayrollButton => 'Load Payroll';

  @override
  String get payrollCsvCopiedMessage => 'Payroll CSV copied to clipboard';

  @override
  String get commissionLabel => 'Commission: ';

  @override
  String get rideStatusHandedOff => 'Handed Off';

  @override
  String get handOffRide => 'Hand Off Ride';

  @override
  String get handOffRideTitle => 'Hand Off Ride';

  @override
  String get handOffPartnerCompany => 'Partner Company';

  @override
  String get handOffExternalDriver => 'External Driver';

  @override
  String get handOffSelectCompany => 'Select company';

  @override
  String get handOffSelectDriver => 'Select driver';

  @override
  String get handOffAddNewCompany => '+ Add new company';

  @override
  String get handOffAddNewDriver => '+ Add new driver';

  @override
  String get handOffCompanyName => 'Company name *';

  @override
  String get handOffDriverName => 'Driver name *';

  @override
  String get handOffPhoneOptional => 'Phone (optional)';

  @override
  String get handOffButton => 'Hand Off';

  @override
  String get rideHandedOffInfo => 'Ride handed off to the external partner.';

  @override
  String handOffFailed(String message) {
    return 'Hand-off failed: $message';
  }

  @override
  String get closeRide => 'Close';

  @override
  String get closeRideTitle => 'Close ride?';

  @override
  String get closeRideConfirmMessage =>
      'This will cancel the unassigned ride. The client will be notified.';

  @override
  String get closeRideButton => 'Close ride';

  @override
  String get confirmRide => 'Confirm Ride';

  @override
  String get rejectRide => 'Reject Ride';

  @override
  String get rejectReasonPrompt => 'Reason for rejection';

  @override
  String get rejectButton => 'Reject';

  @override
  String get rejectReasonTooFar => 'Pickup too far';

  @override
  String get rejectReasonBusy => 'Busy with another ride';

  @override
  String get rejectReasonBreak => 'On break / end of shift';

  @override
  String get rejectReasonVehicleIssue => 'Vehicle issue';

  @override
  String get rejectReasonOther => 'Other';

  @override
  String get rideConfirmed => 'Ride confirmed';

  @override
  String get rideRejected => 'Ride rejected';

  @override
  String get confirmationRequestTitle => 'Ride confirmation needed';

  @override
  String get confirmationRequestBody =>
      'Please confirm or reject your assigned ride';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get ridesTab => 'Rides';

  @override
  String get createTab => 'Create';

  @override
  String get frontDeskTitle => 'Front desk';

  @override
  String get quickBook => 'Quick book';

  @override
  String get bookedToday => 'Booked today';

  @override
  String get awaitingConfirm => 'Awaiting confirm';

  @override
  String get activeClientsLabel => 'Active clients';

  @override
  String get templatesLabel => 'Templates';

  @override
  String get todaysBookings => 'Today\'s bookings';

  @override
  String get noRidesToday => 'No rides today';

  @override
  String get loadRidesToSeeBookings => 'Load rides to see today\'s bookings';

  @override
  String get manageClientsTitle => 'Manage Clients';

  @override
  String get searchClientsHint => 'Search clients...';

  @override
  String get noClientsMatchSearch => 'No clients match your search';

  @override
  String get noClientsYet => 'No clients yet';

  @override
  String get addClientTitle => 'Add Client';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get addButton => 'Add';

  @override
  String get editAction => 'Edit';

  @override
  String get duplicateRideAction => 'Duplicate';

  @override
  String get deactivateAction => 'Deactivate';

  @override
  String get editClientTitle => 'Edit Client';

  @override
  String get clientUpdatedSuccess => 'Client updated successfully';

  @override
  String get clientUpdateFailed => 'Failed to update client. Please try again.';

  @override
  String get deactivateClientTitle => 'Deactivate Client';

  @override
  String deactivateClientConfirmMsg(String name) {
    return 'Are you sure you want to deactivate $name?';
  }

  @override
  String get newRideButton => 'New Ride';

  @override
  String get ridesCountLabel => 'rides';

  @override
  String get preferredDriverAssigned => 'Preferred driver assigned';

  @override
  String get noRidesYet => 'No rides yet';

  @override
  String get clientCompanyFieldLabel => 'Company';

  @override
  String get clientCompanyNone => 'No company';

  @override
  String get vipClientLabel => 'VIP Client';

  @override
  String get vipClientHelpText => 'Priority service and preferred driver';

  @override
  String driverLabel(String name) {
    return 'Driver: $name';
  }

  @override
  String get reportsTitle => 'Reports';

  @override
  String get totalRidesLabel => 'Total Rides';

  @override
  String get inProgressLabel => 'In Progress';

  @override
  String get requestedLabel => 'Requested';

  @override
  String get assignedLabel => 'Assigned';

  @override
  String get keyMetrics => 'Key Metrics';

  @override
  String get cancellationRateLabel => 'Cancellation Rate';

  @override
  String get statusBreakdown => 'Status Breakdown';

  @override
  String get noRideDataYet => 'No ride data yet';

  @override
  String get noActiveRides => 'You have no active rides';

  @override
  String get useBookTabHint => 'Use \"Book\" tab to create one';

  @override
  String get trackDriver => 'Track driver';

  @override
  String departureTimeReachedFlight(String flightInfo) {
    return 'Departure time reached for flight $flightInfo';
  }

  @override
  String failedToCancelRide(String error) {
    return 'Failed to cancel ride: $error';
  }

  @override
  String get failedToLoadRides => 'Failed to load rides';

  @override
  String get goodMorning => 'Good morning,';

  @override
  String get goodAfternoon => 'Good afternoon,';

  @override
  String get goodEvening => 'Good evening,';

  @override
  String get whereTo => 'Where to?';

  @override
  String get onTrip => 'On trip';

  @override
  String get driverOnTheWay => 'Driver on the way';

  @override
  String get driverAssigned => 'Driver assigned';

  @override
  String get yourDriver => 'Your driver';

  @override
  String get savedPlaces => 'SAVED PLACES';

  @override
  String get savedPlaceHome => 'Home';

  @override
  String get savedPlaceOffice => 'Office';

  @override
  String get addAddress => 'Add address';

  @override
  String get useThisAddress => 'Use this address';

  @override
  String get editAddress => 'Edit address';

  @override
  String get removeAddress => 'Remove';

  @override
  String get removeAddressConfirm => 'Remove this saved place?';

  @override
  String get myAddresses => 'MY ADDRESSES';

  @override
  String get manageAddresses => 'Saved addresses';

  @override
  String get addCustomAddress => 'Add new place';

  @override
  String get addressLabel => 'Label';

  @override
  String get addressLabelHint => 'e.g. Gym, Parents';

  @override
  String get labelRequired => 'Please enter a label';

  @override
  String get bookARide => 'Book a ride';

  @override
  String get scheduled => 'SCHEDULED';

  @override
  String get nowLabel => 'NOW';

  @override
  String get asap => 'ASAP';

  @override
  String get vehicleClass => 'VEHICLE CLASS';

  @override
  String get estimatedTotal => 'Estimated total';

  @override
  String get estimateUnavailableHint =>
      'We couldn\'t estimate the price for this address. You can still book — the fare will be confirmed afterwards.';

  @override
  String get confirmBooking => 'Confirm booking';

  @override
  String get rideBookedSuccessfully => 'Ride booked successfully!';

  @override
  String get failedToCreateRide => 'Failed to create ride';

  @override
  String get failedToLoadRideHistory => 'Failed to load ride history';

  @override
  String get listView => 'List';

  @override
  String get pastLabel => 'PAST';

  @override
  String get confirmedStatus => 'Confirmed';

  @override
  String get rateThisRide => 'Rate this ride';

  @override
  String get thankYouForRating => 'Thank you for your rating!';

  @override
  String failedToSubmitRating(String error) {
    return 'Failed to submit rating: $error';
  }

  @override
  String rideCardTimeLabel(String time) {
    return 'Time: $time';
  }

  @override
  String get deleteConfirmationTitle => 'Confirmation';

  @override
  String deleteRideConfirmMessage(String from, String to) {
    return 'Delete ride $from → $to?';
  }

  @override
  String get cancelRideDialogTitle => 'Cancel Ride';

  @override
  String get selectCancellationReason =>
      'Please select a reason for cancellation:';

  @override
  String get cancellationReasonLabel => 'Reason';

  @override
  String get cancellationReasonClientRequest => 'Client Request';

  @override
  String get cancellationReasonWeather => 'Weather';

  @override
  String get cancellationReasonOther => 'Other';

  @override
  String get cancellationReasonClientNoShow => 'Client No-Show';

  @override
  String get cancellationReasonDriverUnavailable => 'Driver Unavailable';

  @override
  String get cancellationReasonVehicleIssue => 'Vehicle Issue';

  @override
  String get cancellationFeeLabel => 'Cancellation Fee (optional)';

  @override
  String get rateRideExperienceQuestion => 'How was your experience?';

  @override
  String get rateRideCommentLabel => 'Comment (optional)';

  @override
  String get rateRideCommentHint => 'Tell us about your experience...';

  @override
  String get airportTransferLabel => 'Airport Transfer';

  @override
  String get airportTransferHint =>
      'Enable if this is an airport pickup/drop-off';

  @override
  String get airportDepartureLabel => 'Departure';

  @override
  String get airportDepartureHint => 'To airport';

  @override
  String get airportArrivalLabel => 'Arrival';

  @override
  String get airportArrivalHint => 'From airport';

  @override
  String get flightNumberLabel => 'Flight Number';

  @override
  String get flightNumberHint => 'e.g. LH123, BA456';

  @override
  String get flightNumberRequired => 'Flight number is required';

  @override
  String get flightNumberInvalidFormat =>
      'Enter a valid flight number, e.g. LH429';

  @override
  String get gateLabel => 'Gate';

  @override
  String get terminalLabel => 'Terminal';

  @override
  String get gateRemote => 'Bus gate (remote stand)';

  @override
  String get creatingRideLabel => 'Creating Ride...';

  @override
  String get createRideButton => 'Create Ride';

  @override
  String get clearFormButton => 'Clear Form';

  @override
  String get vehicleInformationLabel => 'Vehicle Information';

  @override
  String get messageButton => 'Message';

  @override
  String get routeInformationLabel => 'Route Information';

  @override
  String get pickupTimeLabel => 'Pickup Time';

  @override
  String get distanceLabel => 'Distance';

  @override
  String get durationLabel => 'Duration';

  @override
  String get etaToClientLabel => 'ETA to client';

  @override
  String get openInGoogleMapsButton => 'Open in Google Maps';

  @override
  String get rideStatusLabel => 'Ride Status';

  @override
  String get rideHasBeenCancelledLabel => 'This ride has been cancelled';

  @override
  String get rideStatusRequestedClientLabel => 'Waiting for driver assignment';

  @override
  String get rideStatusRequestedStaffLabel => 'Awaiting assignment';

  @override
  String get rideStatusAssignedEnRouteLabel => 'Driver is on the way';

  @override
  String get rideStatusAssignedLabel => 'Driver assigned';

  @override
  String get rideStatusAssignedDriverLabel => 'You are assigned to this ride';

  @override
  String get rideStatusInProgressClientLabel => 'Ride in progress';

  @override
  String get rideStatusInProgressDriverLabel => 'Drive safely';

  @override
  String get rideStatusCompletedLabel => 'Completed successfully';

  @override
  String get rideStatusCancelledLabel => 'Ride cancelled';

  @override
  String get rideStatusHandedOffLabel => 'Handed off to partner';

  @override
  String get rideStatusConfirmedClientLabel => 'Driver confirmed your ride';

  @override
  String get rideStatusConfirmedDriverLabel => 'You confirmed this ride';

  @override
  String get rideStatusConfirmedDriverReadyLabel =>
      'You confirmed this ride — ready to start';

  @override
  String get authenticationRequiredError => 'Authentication required';

  @override
  String get selectOrCreateClientError => 'Please select or create a client';

  @override
  String get enterClientNameError => 'Please enter client name';

  @override
  String get enterFromAddressError => 'Please enter the pickup address';

  @override
  String get enterToAddressError => 'Please enter the destination address';

  @override
  String get addressesMustDifferError =>
      'Pickup and destination must be different';

  @override
  String get selectPickupTimeError => 'Please select a pickup time';

  @override
  String get selectFlightDepartureError =>
      'Please select the flight departure time';

  @override
  String get editRideDialogTitle => 'Edit Ride';

  @override
  String get pickupDateTimeLabel => 'Pickup date/time';

  @override
  String get flightNumberOptionalLabel => 'Flight number (optional)';

  @override
  String get notesOptionalLabel => 'Notes (optional)';

  @override
  String serverErrorMessage(String statusCode) {
    return 'Server error: $statusCode';
  }

  @override
  String get useDispatcherDashboardInfo =>
      'Use the Dispatcher Dashboard to assign drivers';

  @override
  String get updateLocationTitle => 'Update Location';

  @override
  String get tellDriverWhereYouAreLabel => 'Tell the driver where you are now:';

  @override
  String get quickSelectLabel => 'Quick select:';

  @override
  String get locationQuickMainEntrance => 'At main entrance';

  @override
  String get locationQuickBaggageClaim => 'At baggage claim';

  @override
  String get locationQuickCafe => 'At cafe';

  @override
  String get locationQuickParking => 'At parking';

  @override
  String get locationQuickInformationDesk => 'At information desk';

  @override
  String get locationQuickSecondFloor => 'On second floor';

  @override
  String get locationQuickExit1 => 'At exit #1';

  @override
  String get locationQuickExit2 => 'At exit #2';

  @override
  String get locationQuickOther => 'Other location';

  @override
  String get orSpecifyExactlyLabel => 'Or specify exactly:';

  @override
  String get locationExampleHint => 'Example: \"At Terminal A entrance\"';

  @override
  String get additionalInstructionsLabel =>
      'Additional instructions (optional):';

  @override
  String get additionalInstructionsExampleHint =>
      'Example: \"Standing near the coffee shop\"';

  @override
  String get specifyLocationError => 'Please specify your location';

  @override
  String get failedToUpdateLocationError =>
      'Failed to update location. Please try again.';

  @override
  String get callClientTooltip => 'Call Client';

  @override
  String get navigateTooltip => 'Navigate';

  @override
  String get delayByHowLongTitle => 'Delay by how long?';

  @override
  String minutesLabel(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get appSubtitle => 'Smart Mobility Solutions';

  @override
  String get orLabel => 'or';

  @override
  String get touchIdLabel => 'Touch ID';

  @override
  String get biometricsLabel => 'Biometrics';

  @override
  String get biometricSetupTitle => 'Biometric Setup';

  @override
  String get biometricSetupMessage =>
      'Would you like to enable quick login using biometrics?\n\nThis will allow you to sign in using Face ID, Touch ID, or fingerprint.';

  @override
  String get laterButton => 'Later';

  @override
  String get enableButton => 'Enable';

  @override
  String get createButton => 'Create';

  @override
  String get allLabel => 'All';

  @override
  String get statusLabel => 'Status';

  @override
  String operationFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get roleLabel => 'Role';

  @override
  String get addGeofenceTooltip => 'Add geofence';

  @override
  String get savedTemplatesTitle => 'Saved templates';

  @override
  String get createTemplateDialogTitle => 'Create Template';

  @override
  String get templateNameLabel => 'Template Name';

  @override
  String get fromAddressLabel => 'From Address';

  @override
  String get toAddressLabel => 'To Address';

  @override
  String get templatePickupTimeLabel => 'Pickup Time (HH:mm)';

  @override
  String get recurrenceLabel => 'Recurrence';

  @override
  String get recurrenceDaily => 'Daily';

  @override
  String get recurrenceWeekdays => 'Weekdays';

  @override
  String get recurrenceWeeklyMonday => 'Weekly Monday';

  @override
  String get recurrenceWeeklyTuesday => 'Weekly Tuesday';

  @override
  String get recurrenceWeeklyWednesday => 'Weekly Wednesday';

  @override
  String get recurrenceWeeklyThursday => 'Weekly Thursday';

  @override
  String get recurrenceWeeklyFriday => 'Weekly Friday';

  @override
  String get recurrenceSaturdayLabel => 'Weekly Saturday';

  @override
  String get recurrenceSundayLabel => 'Weekly Sunday';

  @override
  String get priceOptionalLabel => 'Price (optional)';

  @override
  String get generateRidesMenuLabel => 'Generate rides';

  @override
  String get deactivateTemplateMenuLabel => 'Deactivate';

  @override
  String get noTemplatesYet => 'No templates yet';

  @override
  String get noTemplatesSubtitle =>
      'Create a template to schedule recurring rides';

  @override
  String get addTemplateButton => 'Add template';

  @override
  String get ridesGeneratedSuccess => 'Rides generated successfully';

  @override
  String failedToGenerateRides(String error) {
    return 'Failed to generate rides: $error';
  }

  @override
  String failedToDeactivateTemplate(String error) {
    return 'Failed to deactivate: $error';
  }

  @override
  String get templateBadgeActive => 'Active';

  @override
  String get templateBadgePaused => 'Paused';

  @override
  String get geofenceScreenTitle => 'Geofences';

  @override
  String get zonesTabLabel => 'Zones';

  @override
  String get recentAlertsTabLabel => 'Recent Alerts';

  @override
  String get createGeofenceDialogTitle => 'Create Geofence';

  @override
  String get zoneNameLabel => 'Zone name';

  @override
  String get geofenceTypeLabel => 'Type';

  @override
  String get geofenceTypeServiceArea => 'Service Area';

  @override
  String get geofenceTypeClientPickup => 'Client Pickup';

  @override
  String get geofenceTypeCustomZone => 'Custom Zone';

  @override
  String get latitudeLabel => 'Latitude';

  @override
  String get longitudeLabel => 'Longitude';

  @override
  String get radiusLabel => 'Radius';

  @override
  String get notifyOnEntryLabel => 'Notify on entry';

  @override
  String get notifyOnExitLabel => 'Notify on exit';

  @override
  String get noGeofenceZonesYet => 'No geofence zones yet';

  @override
  String get createZonesToMonitorSubtitle =>
      'Create zones to monitor driver entry and exit events';

  @override
  String get createZoneButton => 'Create zone';

  @override
  String get deleteZoneConfirmTitle => 'Delete zone';

  @override
  String deleteZoneConfirmMsg(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get geofenceDeletedSuccess => 'Geofence deleted';

  @override
  String failedToDeleteGeofence(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String failedToToggleGeofence(String code) {
    return 'Failed to toggle geofence ($code)';
  }

  @override
  String failedToCreateGeofence(String code) {
    return 'Failed to create geofence ($code)';
  }

  @override
  String get geofenceCreatedSuccess => 'Geofence created';

  @override
  String get fillRequiredFieldsError => 'Please fill in all required fields';

  @override
  String get noAlertsFound => 'No alerts found';

  @override
  String driverEnteredGeofence(String geofenceName) {
    return 'Driver entered $geofenceName';
  }

  @override
  String driverLeftGeofence(String geofenceName) {
    return 'Driver left $geofenceName';
  }

  @override
  String get alertFilterAll => 'All';

  @override
  String get alertFilterEntry => 'Entry';

  @override
  String get alertFilterExit => 'Exit';

  @override
  String get alertFilterLabel => 'Filter:';

  @override
  String geofenceSubtitleAirport(int radius) {
    return 'Airport zone · ${radius}m radius';
  }

  @override
  String geofenceSubtitleServiceArea(int radius) {
    return 'Service area · ${radius}m radius';
  }

  @override
  String geofenceSubtitleClientPickup(int radius) {
    return 'Client pickup point · ${radius}m radius';
  }

  @override
  String geofenceSubtitleCustomZone(int radius) {
    return 'Custom zone · ${radius}m radius';
  }

  @override
  String failedToLoadGeofences(String code) {
    return 'Failed to load geofences ($code)';
  }

  @override
  String failedToLoadAlerts(String code) {
    return 'Failed to load alerts ($code)';
  }

  @override
  String get notifTabNotifications => 'Notifications';

  @override
  String get notifTabSettings => 'Settings';

  @override
  String get markAllReadButton => 'Mark all read';

  @override
  String get clearAllNotificationsMenuLabel => 'Clear All';

  @override
  String get clearAllConfirmTitle => 'Clear All Notifications';

  @override
  String get clearAllConfirmContent =>
      'Are you sure you want to delete all notifications?';

  @override
  String get deleteAllNotificationsButton => 'Delete All';

  @override
  String get noNotificationsYet => 'No notifications';

  @override
  String get notifFilterAll => 'All';

  @override
  String get notifFilterRides => 'Rides';

  @override
  String get notifFilterChat => 'Chat';

  @override
  String get notifFilterGeofence => 'Geofence';

  @override
  String get notifFilterPools => 'Pools';

  @override
  String get notifFilterCheckpoints => 'Checkpoints';

  @override
  String get notifJustNow => 'Just now';

  @override
  String notifMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String notifHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String notifDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get notifPrefSectionPush => 'Push Notifications';

  @override
  String get notifPrefSectionAdditional => 'Additional Channels';

  @override
  String get notifPrefRideUpdatesSubtitle => 'Status changes, assignments';

  @override
  String get notifPrefChatMessagesSubtitle => 'New messages from driver/client';

  @override
  String get notifPrefDriverApproachingLabel => 'Driver Approaching';

  @override
  String get notifPrefDriverApproachingSubtitle => 'When driver is near pickup';

  @override
  String get notifPrefGeofenceAlertsLabel => 'Geofence Alerts';

  @override
  String get notifPrefGeofenceAlertsSubtitle => 'Entry/exit zone alerts';

  @override
  String get notifPrefPoolUpdatesLabel => 'Pool Updates';

  @override
  String get notifPrefPoolUpdatesSubtitle => 'Ride pooling notifications';

  @override
  String get notifPrefEmailLabel => 'Email Notifications';

  @override
  String get notifPrefEmailSubtitle => 'Receive notifications via email';

  @override
  String get notifPrefSmsLabel => 'SMS Notifications';

  @override
  String get notifPrefSmsSubtitle => 'Receive notifications via SMS';

  @override
  String get notifPrefQuietHours => 'Quiet Hours';

  @override
  String get notifPrefQuietHoursFrom => 'From';

  @override
  String get notifPrefQuietHoursTo => 'To';

  @override
  String get notifPrefNotSet => 'Not set';

  @override
  String get savePreferencesButton => 'Save Preferences';

  @override
  String get preferencesSaved => 'Preferences saved';

  @override
  String get revokeSessionDialogTitle => 'Revoke Session';

  @override
  String get revokeSessionDialogContent =>
      'This will log out the device associated with this session.';

  @override
  String get revokeSessionButton => 'Revoke';

  @override
  String get revokeAllOtherSessionsDialogTitle => 'Revoke All Other Sessions';

  @override
  String get revokeAllOtherSessionsDialogContent =>
      'This will log out all other devices. Only your current session will remain active.';

  @override
  String get revokeAllButton => 'Revoke All';

  @override
  String get sessionRevoked => 'Session revoked';

  @override
  String get allOtherSessionsRevoked => 'All other sessions revoked';

  @override
  String get noActiveSessions => 'No active sessions';

  @override
  String get sessionCurrentLabel => 'Current';

  @override
  String sessionIpLabel(String ip) {
    return 'IP: $ip';
  }

  @override
  String sessionCreatedLabel(String date) {
    return 'Created: $date';
  }

  @override
  String sessionLastActiveLabel(String date) {
    return 'Last active: $date';
  }

  @override
  String get revokeSessionAction => 'Revoke';

  @override
  String get userManagementTitle => 'User Management';

  @override
  String get createUserDialogTitle => 'Create User';

  @override
  String get searchUsersHint => 'Search users...';

  @override
  String get changeRoleMenuHeader => 'Change Role';

  @override
  String get changeStatusMenuHeader => 'Change Status';

  @override
  String get activateUserAction => 'Activate';

  @override
  String get suspendUserAction => 'Suspend';

  @override
  String get deactivateUserAction => 'Deactivate';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get totalUsersLabel => 'Total';

  @override
  String get driversStatLabel => 'Drivers';

  @override
  String get clientsStatLabel => 'Clients';

  @override
  String get staffStatLabel => 'Staff';

  @override
  String roleChangedSuccess(String role) {
    return 'Role updated to $role';
  }

  @override
  String statusChangedSuccess(String status) {
    return 'Status updated to $status';
  }

  @override
  String failedToChangeRole(String error) {
    return 'Failed: $error';
  }

  @override
  String failedToChangeStatus(String error) {
    return 'Failed: $error';
  }

  @override
  String failedToCreateUser(String error) {
    return 'Failed: $error';
  }

  @override
  String get blacklistTitle => 'Blacklist';

  @override
  String get addBlacklistEntryDialogTitle => 'Add Blacklist Entry';

  @override
  String get clientIdLabel => 'Client ID';

  @override
  String get driverIdLabel => 'Driver ID';

  @override
  String get reasonOptionalLabel => 'Reason (optional)';

  @override
  String get clientDriverIdRequired => 'Client ID and Driver ID are required';

  @override
  String get removeBlacklistEntryDialogTitle => 'Remove Blacklist Entry';

  @override
  String get removeBlacklistEntryContent =>
      'Are you sure you want to remove this blacklist entry?';

  @override
  String get removeBlacklistEntryButton => 'Remove';

  @override
  String get noBlacklistEntries => 'No blacklist entries';

  @override
  String get tenantsTitle => 'Tenants';

  @override
  String tenantsWithCount(int count) {
    return 'Tenants · $count companies';
  }

  @override
  String get onboardButton => '+ Onboard';

  @override
  String get noTenantsFound => 'No tenants found';

  @override
  String get onboardCompanyDialogTitle => 'Onboard Company';

  @override
  String get editCompanyDialogTitle => 'Edit Company';

  @override
  String get subscriptionPlanLabel => 'Subscription Plan';

  @override
  String get colHeaderCompany => 'COMPANY';

  @override
  String get colHeaderPlan => 'PLAN';

  @override
  String get colHeaderDrivers => 'DRIVERS';

  @override
  String get colHeaderRidesPerMonth => 'RIDES / MO';

  @override
  String get colHeaderStatus => 'STATUS';

  @override
  String get deactivateCompanyDialogTitle => 'Deactivate Company?';

  @override
  String deactivateCompanyDialogContent(String name) {
    return 'Are you sure you want to deactivate \"$name\"?\n\nThe company will be marked as Inactive but all data (rides, invoices, users) will be preserved.';
  }

  @override
  String get setActiveAction => 'Set Active';

  @override
  String get setTrialAction => 'Set Trial';

  @override
  String get suspendAction => 'Suspend';

  @override
  String get emergencyReassignmentTitle => 'Emergency Reassignments';

  @override
  String get emergencyReassignmentDialogTitle => 'Emergency Reassignment';

  @override
  String get rideIdLabel => 'Ride ID';

  @override
  String get emergencyReasonLabel => 'Reason';

  @override
  String get availableDriversLabel => 'Available Drivers:';

  @override
  String get newDriverIdLabel => 'New Driver ID (optional)';

  @override
  String get newDriverIdHelper =>
      'Leave empty to unassign and return to pending';

  @override
  String get reassignButton => 'Reassign';

  @override
  String get rideIdRequired => 'Ride ID is required';

  @override
  String get emergencyReassignmentCreated => 'Emergency reassignment created';

  @override
  String get noEmergencyReassignments => 'No emergency reassignments';

  @override
  String get emergencyReasonDriverIllness => 'Driver Illness';

  @override
  String get emergencyReasonVehicleBreakdown => 'Vehicle Breakdown';

  @override
  String get emergencyReasonDriverNoShow => 'Driver No-Show';

  @override
  String get emergencyReasonAccident => 'Accident';

  @override
  String get emergencyReasonPersonalEmergency => 'Personal Emergency';

  @override
  String get emergencyReasonOther => 'Other';

  @override
  String get preferredDriverLabel => 'Preferred';

  @override
  String emergencyRideLabel(String id) {
    return 'Ride: $id';
  }

  @override
  String emergencyOriginalDriverLabel(String id) {
    return 'Original driver: $id';
  }

  @override
  String emergencyNewDriverLabel(String id) {
    return 'New driver: $id';
  }

  @override
  String get ridePoolsTitle => 'Ride Pools';

  @override
  String get createRidePoolDialogTitle => 'Create Ride Pool';

  @override
  String get poolNameOptionalLabel => 'Pool Name (optional)';

  @override
  String get poolNameHint => 'e.g., Airport Morning Shuttle';

  @override
  String get routeDirectionOptionalLabel => 'Route Direction (optional)';

  @override
  String get routeDirectionHint => 'e.g., City Center → Airport';

  @override
  String get maxPassengersLabel => 'Max Passengers:';

  @override
  String get ridePoolCreated => 'Ride pool created';

  @override
  String get noRidePools => 'No ride pools';

  @override
  String get createPoolToCombineRides => 'Create a pool to combine rides';

  @override
  String errorLoadingPoolDetails(String error) {
    return 'Error loading pool details: $error';
  }

  @override
  String get poolDetailStatusLabel => 'Status';

  @override
  String get poolDetailPassengersLabel => 'Passengers';

  @override
  String get poolDetailRouteLabel => 'Route';

  @override
  String get poolDetailDriverLabel => 'Driver';

  @override
  String get poolMembersLabel => 'Members:';

  @override
  String get noRidesInPool => 'No rides in this pool yet';

  @override
  String get companySettingsTitle => 'Company Settings';

  @override
  String get navItemCompany => 'Company';

  @override
  String get navItemUsersRoles => 'Users & Roles';

  @override
  String get navItemCompliance => 'Compliance';

  @override
  String get navItemBillingDatev => 'Billing & DATEV';

  @override
  String get navItemGeofences => 'Geofences';

  @override
  String get companyProfileSectionTitle => 'Company profile';

  @override
  String get companyProfileSubtitle =>
      'Legal entity information displayed on invoices and reports.';

  @override
  String get complianceSectionTitle => 'Compliance & Security';

  @override
  String get complianceSubtitle =>
      'Data privacy, access management, and audit controls.';

  @override
  String get billingDatevSectionTitle => 'Billing & DATEV';

  @override
  String get billingDatevSubtitle =>
      'Tariff configuration and DATEV export settings.';

  @override
  String get tariffSettingsSectionTitle => 'Tariff Settings';

  @override
  String get datevIntegrationSectionTitle => 'DATEV Integration';

  @override
  String get datevIntegrationSubtitle =>
      'Beraternummer und Mandantennummer werden im EXTF-Buchungsstapel-Header verwendet.';

  @override
  String get legalNameLabel => 'Legal name';

  @override
  String get vatIdLabel => 'VAT ID';

  @override
  String get defaultCurrencyLabel => 'Default currency';

  @override
  String get timezoneLabel => 'Timezone';

  @override
  String get commissionRateLabel => 'Commission Rate (%)';

  @override
  String get cancellationFeeSettingsLabel => 'Cancellation Fee (€)';

  @override
  String get noShowFeeLabel => 'No-Show Fee (€)';

  @override
  String get basePriceLabel => 'Base Price (€)';

  @override
  String get pricePerKmLabel => 'Price per Km (€)';

  @override
  String get airportSurchargeLabel => 'Airport Surcharge (€)';

  @override
  String get nightSurchargeLabel => 'Night Surcharge (€)';

  @override
  String get workStartLabel => 'Work Start';

  @override
  String get workEndLabel => 'Work End';

  @override
  String get settingsSavedSuccess => 'Settings saved successfully';

  @override
  String failedToSaveSettings(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get gdprExportTitle => 'GDPR export';

  @override
  String get gdprExportSubtitle => 'Download all personal data';

  @override
  String get auditLogTitle => 'Audit log';

  @override
  String get auditLogSubtitle => 'Review system activity';

  @override
  String get activeSessionsCardTitle => 'Active sessions';

  @override
  String get activeSessionsCardSubtitle => 'Manage logged-in devices';

  @override
  String get blacklistCardTitle => 'Blacklist';

  @override
  String get blacklistCardSubtitle => 'Manage blocked accounts';

  @override
  String comingSoonLabel(String label) {
    return '$label coming soon';
  }

  @override
  String get settingsCompanyProfile => 'Company Profile';

  @override
  String get generalSettingsSectionTitle => 'General Settings';

  @override
  String get gdprScreenTitle => 'Privacy & Data (GDPR)';

  @override
  String get consentManagementSectionTitle => 'Consent Management';

  @override
  String get consentDataProcessingLabel => 'Data Processing';

  @override
  String get consentDataProcessingSubtitle =>
      'Allow processing of ride and account data';

  @override
  String get consentMarketingLabel => 'Marketing';

  @override
  String get consentMarketingSubtitle =>
      'Receive promotional emails and offers';

  @override
  String get consentAnalyticsLabel => 'Analytics';

  @override
  String get consentAnalyticsSubtitle =>
      'Help improve the app with usage analytics';

  @override
  String get consentThirdPartySharingLabel => 'Third-Party Sharing';

  @override
  String get consentThirdPartySharingSubtitle =>
      'Share data with partner services';

  @override
  String get yourDataSectionTitle => 'Your Data';

  @override
  String get exportMyDataLabel => 'Export My Data';

  @override
  String get exportMyDataSubtitle =>
      'Download all personal data we have stored about you';

  @override
  String get dataDeletionSectionTitle => 'Data Deletion';

  @override
  String get requestDataDeletionLabel => 'Request Data Deletion';

  @override
  String get requestDataDeletionSubtitle =>
      'Permanently delete all your data and account';

  @override
  String get pendingDeletionSubtitle => 'A deletion request is already pending';

  @override
  String get pendingChipLabel => 'Pending';

  @override
  String get requestHistoryTitle => 'Request History';

  @override
  String get requestDeletionDialogTitle => 'Request Data Deletion';

  @override
  String get requestDeletionDialogContent =>
      'This will submit a request to delete all your personal data. This action cannot be undone. Your account will be deactivated once the request is processed.\n\nAre you sure you want to proceed?';

  @override
  String get requestDeletionButton => 'Request Deletion';

  @override
  String get dataExportCopied => 'Data export copied to clipboard';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get deletionRequestSubmitted => 'Deletion request submitted';

  @override
  String failedToLoadGdprData(String consentsCode, String requestsCode) {
    return 'Failed to load GDPR data ($consentsCode/$requestsCode)';
  }

  @override
  String get dataDeletionRequestType => 'Data Deletion';

  @override
  String get dataExportRequestType => 'Data Export';

  @override
  String get paymentsTitle => 'Payments';

  @override
  String get unpaidBadgeLabel => 'Unpaid';

  @override
  String get allRidesPaidLabel => 'All rides are paid';

  @override
  String get markAsPaidDialogTitle => 'Mark as Paid';

  @override
  String get paymentMethodLabel => 'Payment Method:';

  @override
  String get paymentMethodSelectLabel => 'Payment Method';

  @override
  String get paymentMethodPayment => 'Payment';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodCard => 'Credit Card';

  @override
  String get paymentMethodInvoice => 'Invoice';

  @override
  String amountLabel(String amount) {
    return 'Amount: $amount EUR';
  }

  @override
  String get confirmPaymentButton => 'Confirm Payment';

  @override
  String get paymentRecordedSuccess => 'Payment recorded';

  @override
  String get failedToLoadUnpaidRides => 'Failed to load unpaid rides';

  @override
  String myRideTitle(String dateTime) {
    return 'My Ride · $dateTime';
  }

  @override
  String rideTitle(String client) {
    return 'Ride · $client';
  }

  @override
  String get confirmationSentLabel => 'Confirmation sent';

  @override
  String get cancellationDetailsTitle => 'Cancellation Details';

  @override
  String cancellationReasonDetail(String reason) {
    return 'Reason: $reason';
  }

  @override
  String cancelledByLabel(String name) {
    return 'Cancelled by: $name';
  }

  @override
  String cancellationFeeDisplay(String fee) {
    return 'Fee: €$fee';
  }

  @override
  String get ratingTitle => 'Rating';

  @override
  String get notesTitle => 'Notes';

  @override
  String get openChatButton => 'Open Chat';

  @override
  String get rideStatusUpdatedSuccess => 'Ride status updated successfully';

  @override
  String failedToUpdateRideStatus(String error) {
    return 'Failed to update ride status: $error';
  }

  @override
  String get driverAssignedSuccess => 'Driver assigned successfully';

  @override
  String failedToAssignDriver(String error) {
    return 'Failed to assign driver: $error';
  }

  @override
  String get rideCancelledSuccess => 'Ride cancelled';

  @override
  String get completeRideDialogTitle => 'Complete Ride';

  @override
  String get completeRideDialogContent => 'Mark this ride as completed?';

  @override
  String get createNewRideTitle => 'Create New Ride';

  @override
  String get rideCreatedSuccess => 'Ride created successfully!';

  @override
  String get conflictDialogTitle => 'Schedule conflict';

  @override
  String conflictDialogContent(String message) {
    return '$message\n\nThe ride was created and is in the dispatcher pool. Assign it to yourself anyway?';
  }

  @override
  String get conflictDialogContentDefault =>
      'You already have a ride around this time. The ride was created and is in the dispatcher pool. Assign it to yourself anyway?';

  @override
  String conflictDialogContentRich(String from, String to, String time) {
    return 'The driver is already booked: $from → $to at $time.\n\nThe ride was created and is in the dispatcher pool. Assign it anyway?';
  }

  @override
  String get keepInPoolButton => 'Keep in pool';

  @override
  String get assignAnywayButton => 'Assign anyway';

  @override
  String get exportRidesTitle => 'Export Rides';

  @override
  String get copyCsvButton => 'Copy CSV';

  @override
  String get dateRangeButton => 'Date Range';

  @override
  String get noRidesMatchFilters => 'No rides match the filters';

  @override
  String get exportSummaryTotal => 'Total';

  @override
  String get exportSummaryCompleted => 'Completed';

  @override
  String get exportSummaryRevenue => 'Revenue';

  @override
  String csvCopiedSnackbar(int count) {
    return 'CSV data copied to clipboard ($count rides)';
  }

  @override
  String get okButton => 'OK';

  @override
  String get flightsMunichAirportTitle => 'Flights · Munich Airport';

  @override
  String get autoSyncedLabel => 'auto-synced';

  @override
  String get arrivalsTabLabel => 'Arrivals';

  @override
  String get arrivalsBoardTitle => 'Arrivals · Munich Airport';

  @override
  String get departuresTabLabel => 'Departures';

  @override
  String get noArrivalsFound => 'No arrivals found';

  @override
  String get noDeparturesFound => 'No departures found';

  @override
  String get flightDetailsTitle => 'Flight details';

  @override
  String get gateNotPublished => 'Gate not published yet';

  @override
  String get trackFlightLive => 'Track live on Flightradar24';

  @override
  String get couldNotOpenFlightTracker => 'Could not open the flight tracker';

  @override
  String errorLoadingFlights(String error) {
    return 'Error loading flights: $error';
  }

  @override
  String get flightColumnFlight => 'Flight';

  @override
  String get flightColumnOriginDest => 'Origin / Dest.';

  @override
  String get flightColumnSched => 'Sched.';

  @override
  String get flightColumnStatus => 'Status';

  @override
  String get flightColumnLinkedRide => 'Linked ride';

  @override
  String get flightStatusOnTime => 'On time';

  @override
  String get flightStatusDelayed => 'Delayed';

  @override
  String get flightStatusBoarding => 'Boarding';

  @override
  String get flightStatusCancelled => 'Cancelled';

  @override
  String get flightStatusUnknown => 'Unknown';

  @override
  String get flightStatusScheduled => 'Scheduled';

  @override
  String get flightStatusDeparted => 'Departed';

  @override
  String get flightStatusEnRoute => 'En route';

  @override
  String get flightStatusLanded => 'Landed';

  @override
  String get flightStatusDiverted => 'Diverted';

  @override
  String get flightInformation => 'Flight Information';

  @override
  String get flightNumber => 'Flight Number';

  @override
  String get arrivalTime => 'Arrival Time';

  @override
  String get departureTime => 'Departure Time';

  @override
  String get flightNotLinked => '— not linked';

  @override
  String get whoCanSeeWhomTitle => 'Who can see whom';

  @override
  String get visibleToAllDispatchers => 'Visible to all dispatchers';

  @override
  String get scheduleHiddenFromOthers => 'Schedule hidden from others';

  @override
  String get noDriversInCompany => 'No drivers in your company.';

  @override
  String failedToUpdateVisibilityError(String error) {
    return 'Failed to update visibility: $error';
  }

  @override
  String get auditLogScreenTitle => 'Audit Log';

  @override
  String get searchByEntityIdHint => 'Search by entity ID...';

  @override
  String get noAuditEntriesFound => 'No audit entries found';

  @override
  String onlineOnRideLabel(String dateTime) {
    return 'Online · ride at $dateTime';
  }

  @override
  String get startConversationSubtitle =>
      'Start the conversation with the driver';

  @override
  String failedToSendMessage(String error) {
    return 'Failed to send: $error';
  }

  @override
  String get totalRidesStatLabel => 'Total Rides';

  @override
  String get onTimeStatLabel => 'On-time';

  @override
  String get completionRateStatLabel => 'Completion rate';

  @override
  String get avgSlackStatLabel => 'Avg Slack';

  @override
  String get gmvStatLabel => 'GMV';

  @override
  String get ridesByTenantTitle => 'Rides by Tenant';

  @override
  String get rideStatusBreakdownTitle => 'Ride Status Breakdown';

  @override
  String get platformActiveSessionsLabel => 'Platform Active Sessions';

  @override
  String get clientPaymentTitle => 'Payment';

  @override
  String get paymentMethodsSectionLabel => 'PAYMENT METHODS';

  @override
  String get corporateInvoiceLabel => 'Corporate invoice';

  @override
  String get addPaymentMethodButton => 'Add payment method';

  @override
  String get shareRideLink => 'Share tracking link';

  @override
  String get trackingLinkCopied => 'Tracking link copied to clipboard';

  @override
  String get bookWithoutClient => 'Without client (from chat)';

  @override
  String get fromChatRide => 'From chat';

  @override
  String get linkClient => 'Add client details';

  @override
  String get calendarSharingTitle => 'Calendar Sharing';

  @override
  String get calendarSharingMenuItem => 'Calendar Sharing';

  @override
  String get shareInvitesSection => 'My invite codes';

  @override
  String get shareCreateInvite => 'Create invite code';

  @override
  String get shareInviteExpiry1Day => '1 day';

  @override
  String get shareInviteExpiry7Days => '7 days';

  @override
  String get shareInviteExpiry30Days => '30 days';

  @override
  String get shareInviteCreatedTitle => 'Invite code created';

  @override
  String get shareInviteCreatedHint =>
      'Send this code to a driver or dispatcher of another company. They enter it in their app under Calendar Sharing.';

  @override
  String get shareCopyCode => 'Copy code';

  @override
  String get shareCodeCopied => 'Code copied to clipboard';

  @override
  String get shareRevoke => 'Revoke';

  @override
  String get shareGrantedSection => 'Who sees my calendar';

  @override
  String get shareSharedWithMeSection => 'Shared with me';

  @override
  String get shareEnterCode => 'Enter code';

  @override
  String get shareRedeemTitle => 'Connect a shared calendar';

  @override
  String get shareRedeemHint => 'Paste the invite code or link';

  @override
  String get shareRedeemConnect => 'Connect';

  @override
  String shareRedeemSuccess(String name) {
    return 'Connected to $name';
  }

  @override
  String get shareUnlink => 'Unlink';

  @override
  String get shareNoInvites => 'No active invite codes';

  @override
  String get shareNoGrants => 'You have not shared your calendar with anyone';

  @override
  String get shareNoSharedWithMe => 'No calendars have been shared with you';

  @override
  String shareValidUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String shareSince(String date) {
    return 'Since $date';
  }

  @override
  String shareActionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get sharedCalendarAvailable => 'Available';

  @override
  String get sharedCalendarBusy => 'Busy';

  @override
  String get sharedCalendarShift => 'Shift';

  @override
  String get sharedCalendarEmptyDay => 'No shifts or busy slots';

  @override
  String get sharedCalendarEmptyWeek => 'No shifts or busy slots this week';

  @override
  String sharedCalendarTimesHint(String company) {
    return 'Shift times as provided by $company';
  }

  @override
  String get sharedWithMeGroupLabel => 'Shared with me';

  @override
  String get myCompanyGroupLabel => 'My company';

  @override
  String get addShiftTooltip => 'Add shift';

  @override
  String get addShiftTitle => 'New shift';

  @override
  String get shiftDateLabel => 'Date';

  @override
  String get shiftStartLabel => 'Start';

  @override
  String get shiftEndLabel => 'End';

  @override
  String get shiftRepeatUntilLabel => 'Repeat daily until (optional)';

  @override
  String get shiftNoteLabel => 'Note (optional)';

  @override
  String get shiftCreateButton => 'Create';

  @override
  String shiftsCreatedSnack(int count) {
    return 'Shifts created: $count';
  }

  @override
  String get shiftOverlapSnack =>
      'The selected time overlaps an existing shift. Multiple shifts per day are allowed — pick a time that doesn\'t overlap.';

  @override
  String get shiftTimeOrderError => 'Start time must be before end time';

  @override
  String get shiftCancelTitle => 'Cancel this shift?';

  @override
  String get shiftCancelButton => 'Cancel shift';

  @override
  String get shiftCancelledSnack => 'Shift cancelled';

  @override
  String get shiftsStripLabel => 'Shifts';

  @override
  String get noShiftsForDay => 'No shifts';
}
