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
  String assignRideDialogTitle(String rideId) {
    return 'Assign Ride #$rideId';
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
  String reassignRideDialogTitle(String rideId) {
    return 'Reassign ride #$rideId';
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
  String get deactivateAction => 'Deactivate';

  @override
  String get editClientTitle => 'Edit Client';

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
}
