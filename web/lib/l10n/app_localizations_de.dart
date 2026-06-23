// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Dispax';

  @override
  String get login => 'Anmelden';

  @override
  String get logout => 'Abmelden';

  @override
  String get email => 'E-Mail';

  @override
  String get password => 'Passwort';

  @override
  String get invalidCredentials => 'Ungültige E-Mail oder Passwort';

  @override
  String get today => 'Heute';

  @override
  String get tomorrow => 'Morgen';

  @override
  String get yesterday => 'Gestern';

  @override
  String get week => 'Woche';

  @override
  String get month => 'Monat';

  @override
  String get all => 'Alle';

  @override
  String get myRides => 'Meine Fahrten';

  @override
  String get history => 'Verlauf';

  @override
  String get map => 'Karte';

  @override
  String get flights => 'Flüge';

  @override
  String get profile => 'Profil';

  @override
  String get calendar => 'Kalender';

  @override
  String get upcoming => 'Bevorstehend';

  @override
  String get settings => 'Einstellungen';

  @override
  String get pendingRides => 'Ausstehende Fahrten';

  @override
  String ridesAwaiting(int count) {
    return '$count Fahrt(en) warten auf Zuweisung';
  }

  @override
  String get driverSchedules => 'Fahrer-Zeitpläne';

  @override
  String get noDriversScheduled => 'Keine Fahrer geplant';

  @override
  String get noPendingRides => 'Keine ausstehenden Fahrten';

  @override
  String get allRidesAssigned => 'Alle Fahrten wurden zugewiesen';

  @override
  String get selectDriver => 'Fahrer auswählen';

  @override
  String get reassignRide => 'Fahrt neu zuweisen';

  @override
  String get confirmReassignment => 'Neuzuweisung bestätigen';

  @override
  String get reassign => 'Neu zuweisen';

  @override
  String get assign => 'Zuweisen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get retry => 'Wiederholen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get searchClientAddress => 'Kunde, Adresse suchen...';

  @override
  String get searchDriverName => 'Fahrername suchen...';

  @override
  String get airport => 'Flughafen';

  @override
  String get available => 'Verfügbar';

  @override
  String get moderate => 'Mittel';

  @override
  String get busy => 'Ausgelastet';

  @override
  String get sortTimeEarliest => 'Zeit (früheste zuerst)';

  @override
  String get sortTimeLatest => 'Zeit (späteste zuerst)';

  @override
  String get sortClientName => 'Kundenname';

  @override
  String nRidesAssigned(int count) {
    return '$count Fahrt(en) zugewiesen';
  }

  @override
  String timeConflicts(int count) {
    return '$count Zeitkonflikt(e)';
  }

  @override
  String get dropHereToAssign => 'Hier ablegen zum Zuweisen';

  @override
  String get todaysHistory => 'Heutiger Verlauf';

  @override
  String get thisWeeksHistory => 'Wochenverlauf';

  @override
  String get thisMonthsHistory => 'Monatsverlauf';

  @override
  String get allTimeHistory => 'Gesamtverlauf';

  @override
  String get rideHistory => 'Fahrtenverlauf';

  @override
  String get myRideHistory => 'Mein Fahrtenverlauf';

  @override
  String get noRideHistory => 'Kein Fahrtenverlauf';

  @override
  String get completedRidesAppearHere =>
      'Abgeschlossene Fahrten erscheinen hier';

  @override
  String get noRidesForPeriod => 'Keine Fahrten für diesen Zeitraum';

  @override
  String get completed => 'Abgeschlossen';

  @override
  String get cancelled => 'Storniert';

  @override
  String get earned => 'Verdient';

  @override
  String get spent => 'Ausgegeben';

  @override
  String get analytics => 'Analytik';

  @override
  String get totalRides => 'Fahrten gesamt';

  @override
  String get completedRides => 'Abgeschlossen';

  @override
  String get cancelledRides => 'Storniert';

  @override
  String get inProgressRides => 'Laufend';

  @override
  String get requestedRides => 'Angefragt';

  @override
  String get assignedRides => 'Zugewiesen';

  @override
  String get activeDrivers => 'Aktive Fahrer';

  @override
  String get totalClients => 'Kunden gesamt';

  @override
  String get todayRevenue => 'Umsatz heute';

  @override
  String get monthlyRevenue => 'Monatsumsatz';

  @override
  String get avgAssignmentTime => 'Ø Zuweisungszeit';

  @override
  String get cancellationRate => 'Stornoquote %';

  @override
  String get driverLoad => 'Fahrerauslastung';

  @override
  String get dailyOverview => 'Tagesübersicht';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Nachricht eingeben...';

  @override
  String get send => 'Senden';

  @override
  String get chatUnavailable =>
      'Chat ist nur während aktiver Fahrten verfügbar';

  @override
  String get noMessages => 'Noch keine Nachrichten';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get accountSettings => 'Konto';

  @override
  String get changePassword => 'Passwort ändern';

  @override
  String get currentPassword => 'Aktuelles Passwort';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get confirmNewPassword => 'Neues Passwort bestätigen';

  @override
  String get passwordChanged => 'Passwort erfolgreich geändert';

  @override
  String get passwordsDoNotMatch => 'Passwörter stimmen nicht überein';

  @override
  String get passwordTooShort => 'Passwort muss mindestens 6 Zeichen lang sein';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get pushNotifications => 'Push-Benachrichtigungen';

  @override
  String get rideUpdates => 'Fahrten-Updates';

  @override
  String get chatMessages => 'Chat-Nachrichten';

  @override
  String get appearance => 'Darstellung';

  @override
  String get theme => 'Thema';

  @override
  String get lightTheme => 'Hell';

  @override
  String get darkTheme => 'Dunkel';

  @override
  String get systemTheme => 'System';

  @override
  String get language => 'Sprache';

  @override
  String get english => 'English';

  @override
  String get german => 'Deutsch';

  @override
  String get ukrainian => 'Ukrainisch';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get name => 'Name';

  @override
  String get phone => 'Telefon';

  @override
  String get profileUpdated => 'Profil erfolgreich aktualisiert';

  @override
  String get uploadPhoto => 'Foto hochladen';

  @override
  String get changePhoto => 'Foto ändern';

  @override
  String get removePhoto => 'Foto entfernen';

  @override
  String get photoUploadedSuccessfully => 'Foto erfolgreich hochgeladen';

  @override
  String get failedToUploadPhoto => 'Foto-Upload fehlgeschlagen';

  @override
  String get security => 'Sicherheit';

  @override
  String get biometricLogin => 'Biometrische Anmeldung';

  @override
  String get about => 'Über';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get termsOfService => 'Nutzungsbedingungen';

  @override
  String get superAdminDashboard => 'Plattform-Admin';

  @override
  String get companies => 'Unternehmen';

  @override
  String get companiesList => 'Unternehmensliste';

  @override
  String get platformAnalytics => 'Plattform-Analyse';

  @override
  String get platformRevenue => 'Plattformumsatz';

  @override
  String get activeConnections => 'Aktive Verbindungen';

  @override
  String get companyStatus => 'Unternehmensstatus';

  @override
  String get subscriptionPlan => 'Abonnementplan';

  @override
  String get billingAnalytics => 'Abrechnungsanalyse';

  @override
  String get connectionAnalytics => 'Verbindungsanalyse';

  @override
  String get superAdminSettings => 'Plattform-Einstellungen';

  @override
  String get addCompany => 'Unternehmen hinzufügen';

  @override
  String get editCompany => 'Unternehmen bearbeiten';

  @override
  String get deleteCompany => 'Unternehmen deaktivieren';

  @override
  String get deactivateCompanyConfirm =>
      'Möchten Sie dieses Unternehmen wirklich deaktivieren? Das Unternehmen wird als Inaktiv markiert, aber alle Daten bleiben erhalten.';

  @override
  String get companyName => 'Unternehmensname';

  @override
  String get companyEmail => 'Unternehmens-E-Mail';

  @override
  String get companyPhone => 'Unternehmenstelefon';

  @override
  String get companyAddress => 'Unternehmensadresse';

  @override
  String get checkpointLanded => 'Gelandet';

  @override
  String get checkpointArrivalsHall => 'Ankunftshalle';

  @override
  String get checkpointTerminalExit => 'Terminalausgang';

  @override
  String get markCheckpointButton => 'Ich bin hier';

  @override
  String get airportCheckpointPanelTitle => 'Mein Standort im Terminal';

  @override
  String checkpointNotifTitle(String checkpoint) {
    return 'Fahrgast hat $checkpoint erreicht';
  }

  @override
  String checkpointNotifBody(String checkpointName) {
    return 'Ihr Fahrgast befindet sich bei $checkpointName.';
  }

  @override
  String get airportExits => 'Flughafen-Ausgänge';

  @override
  String get addAirport => 'Flughafen hinzufügen';

  @override
  String get editAirport => 'Flughafen bearbeiten';

  @override
  String get deleteAirport => 'Flughafen deaktivieren';

  @override
  String get airportCode => 'Flughafen-Code (z. B. MUC)';

  @override
  String get airportName => 'Flughafenname';

  @override
  String get addZone => 'Zone hinzufügen';

  @override
  String get editZone => 'Zone bearbeiten';

  @override
  String get deleteZone => 'Zone löschen';

  @override
  String get terminalCode => 'Terminal (T1, T2, …)';

  @override
  String get checkpointType => 'Checkpoint-Typ';

  @override
  String get displayName => 'Anzeigename';

  @override
  String get latitude => 'Breitengrad';

  @override
  String get longitude => 'Längengrad';

  @override
  String get radiusMeters => 'Radius (Meter)';

  @override
  String get landingGeofence => 'Lande-Geofence';

  @override
  String get pickOnMap => 'Auf Karte wählen';

  @override
  String get scheduleVisibility => 'Zeitplan-Sichtbarkeit';

  @override
  String get allowViewOtherSchedules =>
      'Zeitpläne der Kollegen anzeigen erlauben';

  @override
  String viewingDriverSchedule(String driverName) {
    return 'Ansicht: $driverName';
  }

  @override
  String get flightDepartureTime => 'Abflugzeit';

  @override
  String get manualPickupTimeOptional =>
      'Abholzeit (optional — wird berechnet, falls leer)';

  @override
  String confirmedPickupTime(String time) {
    return 'Bestätigte Abholung: $time';
  }

  @override
  String get pickupTimeComputedAuto =>
      'Automatisch basierend auf dem Abflugzeitpunkt berechnet';

  @override
  String get markUnavailable => 'Als nicht verfügbar markieren';

  @override
  String get driverUnavailable => 'Fahrer nicht verfügbar';

  @override
  String get unavailabilityReason => 'Grund';

  @override
  String get unavailabilityNote => 'Notiz (optional)';

  @override
  String get unavailabilityFrom => 'Von';

  @override
  String get unavailabilityTo => 'Bis';

  @override
  String get unavailabilityReasonLunch => 'Mittagspause';

  @override
  String get unavailabilityReasonVacation => 'Urlaub';

  @override
  String get unavailabilityReasonPersonal => 'Persönlich';

  @override
  String get driverHasScheduleConflict =>
      'Fahrer ist zu dieser Zeit beschäftigt';

  @override
  String get assignAnywayTitle => 'Fahrer beschäftigt';

  @override
  String assignAnywayMessage(String reason) {
    return 'Dieser Fahrer hat einen Zeitkonflikt: $reason. Trotzdem zuweisen?';
  }

  @override
  String get assignAnyway => 'Trotzdem zuweisen';

  @override
  String get unavailabilityCreated =>
      'Nicht-Verfügbarkeit erfolgreich markiert';

  @override
  String get unavailabilityDeleted => 'Nicht-Verfügbarkeit entfernt';

  @override
  String get noUnavailability => 'Keine Nicht-Verfügbarkeiten';

  @override
  String get preferences => 'Einstellungen';

  @override
  String get faceIdUnlock => 'Face ID entsperren';

  @override
  String get darkMode => 'Dunkelmodus';

  @override
  String get general => 'Allgemein';

  @override
  String get activeSessions => 'Aktive Sitzungen';

  @override
  String get earnings => 'Einnahmen';

  @override
  String get myEarnings => 'Meine Einnahmen';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get privacyDataGdpr => 'Datenschutz & Daten (DSGVO)';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signOutConfirm => 'Möchten Sie sich wirklich abmelden?';

  @override
  String get required => 'Pflichtfeld';

  @override
  String get change => 'Ändern';

  @override
  String get failedToChangePassword => 'Passwort konnte nicht geändert werden';

  @override
  String get welcomeBack => 'Willkommen zurück';

  @override
  String get signInSubtitle => 'Melden Sie sich bei Ihrem Dispatch-Konto an.';

  @override
  String get signIn => 'Anmelden';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get faceId => 'Face ID';

  @override
  String get roleDriver => 'Fahrer';

  @override
  String get roleClient => 'Kunde';

  @override
  String get roleSecretary => 'Sekretärin';

  @override
  String get roleClientSecretary => 'Kundensekretärin';

  @override
  String get roleDispatcher => 'Disponent';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleSuperAdmin => 'Super Admin';

  @override
  String get languageSaveFailed => 'Sprache konnte nicht gespeichert werden';

  @override
  String get billingScreenTitle => 'Billing';

  @override
  String get invoicesTab => 'Rechnungen';

  @override
  String get companiesTab => 'Unternehmen';

  @override
  String get billingRidesTab => 'Fahrten';

  @override
  String invoicesCountSubtitle(String month, int count) {
    return '$month · $count Rechnungen';
  }

  @override
  String get outstandingInvoices => 'Ausstehend';

  @override
  String get paidThisMonth => 'Bezahlt (Monat)';

  @override
  String get overdueInvoices => 'Überfällig';

  @override
  String get collectionRate => 'Einzugsquote';

  @override
  String get exportDatevButton => 'Export DATEV';

  @override
  String get createNewInvoiceButton => '+ Neue Rechnung';

  @override
  String get datevExportOpening => 'DATEV Export öffnen...';

  @override
  String get createCompanyFirst => 'Bitte zuerst ein Unternehmen anlegen.';

  @override
  String get newInvoiceTitle => 'Neue Rechnung';

  @override
  String get companiesLabel => 'Unternehmen *';

  @override
  String get createInvoiceButton => 'Rechnung erstellen';

  @override
  String get allInvoicesFilter => 'Alle';

  @override
  String get draftStatusFilter => 'Entwurf';

  @override
  String get sentStatusFilter => 'Gesendet';

  @override
  String get paidStatusFilter => 'Bezahlt';

  @override
  String get invoiceTableHeaderNumber => 'RECHNUNG';

  @override
  String get invoiceTableHeaderClient => 'KUNDE';

  @override
  String get invoiceTableHeaderAmount => 'BETRAG';

  @override
  String get overdueStatus => 'Überfällig';

  @override
  String get paymentReminderSent => 'Zahlungserinnerung versendet';

  @override
  String get viewDetailsMenu => 'Details';

  @override
  String get gobdCompliant =>
      'GoBD-konform — Rechnungen sind unveränderlich archiviert.';

  @override
  String get noCompanies => 'Keine Unternehmen';

  @override
  String get noInvoices => 'Keine Rechnungen';

  @override
  String get editCompanyMenu => 'Bearbeiten';

  @override
  String get deleteCompanyMenu => 'Löschen';

  @override
  String get addCompanyTitle => 'Unternehmen hinzufügen';

  @override
  String get editCompanyTitle => 'Unternehmen bearbeiten';

  @override
  String get companyNameLabel => 'Name *';

  @override
  String get companyEmailLabel => 'E-Mail';

  @override
  String get companyPhoneLabel => 'Telefon';

  @override
  String get companyAddressLabel => 'Adresse';

  @override
  String get invoiceLanguageLabel => 'Rechnungssprache';

  @override
  String get languageStandard => 'Standard';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUkrainian => 'Ukrainisch';

  @override
  String get addCompanyButton => 'Hinzufügen';

  @override
  String get deleteCompanyConfirmTitle => 'Unternehmen löschen?';

  @override
  String deleteCompanyConfirmMsg(String name) {
    return '$name wird gelöscht.';
  }

  @override
  String get downloadPdfTooltip => 'Herunterladen';

  @override
  String get closeTooltip => 'Schließen';

  @override
  String get closeButton => 'Schließen';

  @override
  String pdfPreviewTitle(String number) {
    return 'Vorschau · $number';
  }

  @override
  String get invoiceLineItems => 'Positionen';

  @override
  String get subtotalLabel => 'Zwischensumme';

  @override
  String vatLineLabel(String rate) {
    return 'MwSt. $rate%';
  }

  @override
  String totalLabel(String currency) {
    return 'Gesamt ($currency)';
  }

  @override
  String get autoFillRidesButton => 'Fahrten automatisch laden';

  @override
  String get sendInvoiceButton => 'Rechnung senden';

  @override
  String get markAsPaidButton => 'Als bezahlt markieren';

  @override
  String get pdfDownloadSuccess => 'PDF heruntergeladen';

  @override
  String get downloadPdfButton => 'PDF herunterladen';

  @override
  String get previewButton => 'Vorschau';

  @override
  String reminderBadgeLabel(String date) {
    return 'Erinnert $date';
  }

  @override
  String get invoicesRailLabel => 'Invoices';

  @override
  String get clientsRailLabel => 'Clients';

  @override
  String get datevRailLabel => 'DATEV';

  @override
  String genericError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get unbilledRidesTitle => 'Nicht fakturierte Fahrten';

  @override
  String get selectRidesToBill => 'Fahrten auswählen';

  @override
  String ridesBillingCountSelected(int count) {
    return '$count ausgewählt';
  }

  @override
  String ridesBillingCountAvailable(int count) {
    return '$count Fahrten';
  }

  @override
  String get selectCompanyForBilling =>
      'Wählen Sie ein Unternehmen, um abrechenbare Fahrten zu sehen.';

  @override
  String get noBillableRides => 'Keine abrechenbaren Fahrten';

  @override
  String get receiptTooltip => 'Quittung';

  @override
  String get receiptTitle => 'Quittung';

  @override
  String selectedRidesSummary(String subtotal, String total) {
    return 'Ausgewählt: $subtotal netto · $total gesamt';
  }

  @override
  String get noRidesSelected => 'Keine Fahrten ausgewählt';

  @override
  String get vatPercentLabel => 'MwSt %';

  @override
  String get invoiceCreatedTitle => 'Rechnung erstellt';

  @override
  String invoiceCreatedMsg(String number, int count, String amount) {
    return '$number · $count Fahrten · €$amount';
  }

  @override
  String pdfDownloadError(String error) {
    return 'PDF-Fehler: $error';
  }

  @override
  String receiptDownloadError(String error) {
    return 'Quittung-Fehler: $error';
  }

  @override
  String get datevExportTitle => 'DATEV Export';

  @override
  String noDataForMonth(String monthLabel) {
    return 'Keine Daten für $monthLabel';
  }

  @override
  String get revenueSection => 'Erlöse';

  @override
  String rowsCountLabel(int count) {
    return '$count Zeilen';
  }

  @override
  String get copyCsvTooltip => 'CSV kopieren';

  @override
  String get revenueCsvLabel => 'Erlöse CSV';

  @override
  String get expensesSection => 'Ausgaben';

  @override
  String get expensesCsvLabel => 'Ausgaben CSV';

  @override
  String get summarySection => 'Zusammenfassung';

  @override
  String netIncomeResult(String amount) {
    return 'Ergebnis: $amount';
  }

  @override
  String get copySummaryCsvTooltip => 'Zusammenfassung kopieren';

  @override
  String get summaryCsvLabel => 'Zusammenfassung';

  @override
  String copiedToClipboard(String label) {
    return '$label in die Zwischenablage kopiert';
  }

  @override
  String get copyAllRevenueHeader => '=== Erlöse ===';

  @override
  String get copyAllExpensesHeader => '=== Ausgaben ===';

  @override
  String get copyAllSummaryHeader => '=== Zusammenfassung ===';

  @override
  String get allDatevDataLabel => 'Alle DATEV-Daten';

  @override
  String downloadFailed(String code) {
    return 'Download fehlgeschlagen: $code';
  }

  @override
  String get netIncomeLabel => 'Ergebnis (Netto)';

  @override
  String get copyAllButton => 'Alles kopieren';

  @override
  String get downloadCsvExtfButton => 'Download .csv (EXTF)';

  @override
  String get datevExtfFormatInfo =>
      'DATEV Buchungsstapel Format – Import via DATEV Unternehmen Online';

  @override
  String expensesScreenTitle(String monthLabel) {
    return 'Ausgaben · $monthLabel';
  }

  @override
  String get addExpenseTooltip => 'Ausgabe erfassen';

  @override
  String get captureExpenseTitle => 'Ausgabe erfassen';

  @override
  String get expenseCategoryLabel => 'Kategorie';

  @override
  String get expenseAmountLabel => 'Betrag (EUR)';

  @override
  String get expenseDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get invalidAmountError => 'Bitte gültigen Betrag eingeben';

  @override
  String get deleteExpenseConfirmTitle => 'Ausgabe löschen?';

  @override
  String deleteExpenseConfirmMsg(String category, String amount) {
    return '$category · €$amount wird gelöscht.';
  }

  @override
  String get noExpenses => 'Keine Ausgaben';

  @override
  String get noReceiptWarning => 'Kein Beleg';

  @override
  String get totalExpensesLabel => 'Gesamt';

  @override
  String get newRideAssigned => 'Neue Fahrt zugewiesen';

  @override
  String get newRideAssignedContent =>
      'Ihnen wurde eine neue Fahrt zugewiesen. Möchten Sie sie annehmen?';

  @override
  String get decline => 'Ablehnen';

  @override
  String get accept => 'Annehmen';

  @override
  String get call => 'Anrufen';

  @override
  String get sms => 'SMS';

  @override
  String get completeRideTitle => 'Fahrt abschließen';

  @override
  String get navigate => 'Navigieren';

  @override
  String get navigateTo => 'Navigieren zu';

  @override
  String get googleMapsPickup => 'Google Maps — Abholung';

  @override
  String get googleMapsDropoff => 'Google Maps — Ziel';

  @override
  String get openingNavigation => 'Navigation in Google Maps wird geöffnet...';

  @override
  String arrivingInMinutes(int etaMinutes) {
    return 'Ankunft in $etaMinutes Min.';
  }

  @override
  String get noCompletedRides => 'Noch keine abgeschlossenen Fahrten';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get youreOnline => 'Sie sind online';

  @override
  String get youreOffline => 'Sie sind offline';

  @override
  String get discardChangesTitle => 'Änderungen verwerfen?';

  @override
  String get discardChangesMessage =>
      'Sie haben nicht gespeicherte Fahrtdetails. Wenn Sie die Seite verlassen, gehen sie verloren.';

  @override
  String get stay => 'Bleiben';

  @override
  String get discard => 'Verwerfen';

  @override
  String get bookLabel => 'Buchen';

  @override
  String get monthView => 'Monatsansicht';

  @override
  String get weekView => 'Wochenansicht';

  @override
  String get dayView => 'Tagesansicht';

  @override
  String get board => 'Übersicht';

  @override
  String get goToday => 'Zum heutigen Tag';

  @override
  String get todaysSchedule => 'Heutiger Zeitplan';

  @override
  String get noRidesScheduled => 'Keine Fahrten geplant';

  @override
  String get enjoyYourFreeDay => 'Genießen Sie Ihren freien Tag!';

  @override
  String get callClient => 'Kunden anrufen';

  @override
  String get startNavigation => 'Navigation starten';

  @override
  String get start => 'Starten';

  @override
  String get completeRideButton => 'Abschließen';

  @override
  String get pickupLocation => 'Abholort';

  @override
  String get dropoffLocation => 'Zielort';

  @override
  String couldNotOpenNavigation(String error) {
    return 'Navigation konnte nicht geöffnet werden: $error';
  }

  @override
  String travelTimeMinutes(int minutes) {
    return '$minutes Min. Fahrzeit';
  }

  @override
  String failedToSetPrice(String error) {
    return 'Preis konnte nicht gesetzt werden: $error';
  }

  @override
  String get setRidePrice => 'Fahrtpreis festlegen';

  @override
  String get setPrice => 'Preis festlegen';

  @override
  String get offline => 'Offline';

  @override
  String get acceptingRides => 'Sie nehmen Fahrten an';

  @override
  String get notAcceptingRides => 'Sie nehmen keine Fahrten an';

  @override
  String failedToUpdate(String error) {
    return 'Aktualisierung fehlgeschlagen: $error';
  }

  @override
  String get homeTab => 'Startseite';

  @override
  String get scheduleTab => 'Zeitplan';

  @override
  String get calendarTab => 'Kalender';

  @override
  String get newRideTab => 'Neue Fahrt';

  @override
  String get moreTab => 'Mehr';

  @override
  String get billingTab => 'Abrechnung';

  @override
  String get moreScreenTitle => 'Mehr';

  @override
  String get dispatchBoardTitle => 'Dispositionsbrett';

  @override
  String dispatcherSubtitle(String weekday, String date, int count) {
    return '$weekday, $date · $count aktive Fahrten';
  }

  @override
  String get searchRidesDrivers => 'Fahrten, Fahrer suchen…';

  @override
  String get newRideButtonLabel => 'Neue Fahrt';

  @override
  String get activeRidesLabel => 'Aktive Fahrten';

  @override
  String get atRiskLabel => 'Gefährdet';

  @override
  String get driversOnlineLabel => 'Fahrer online';

  @override
  String get onTimeLabel => 'Pünktlich';

  @override
  String get earningsMenuItem => 'Einnahmen';

  @override
  String get peakHoursMenuItem => 'Stoßzeiten';

  @override
  String get clientValueMenuItem => 'Kundenwert';

  @override
  String get driversMenuItem => 'Fahrer';

  @override
  String get ratingsMenuItem => 'Bewertungen';

  @override
  String get auditLogMenuItem => 'Prüfprotokoll';

  @override
  String get adminMenuItem => 'Administration';

  @override
  String get companyMenuItem => 'Unternehmen';

  @override
  String get expensesMenuItem => 'Ausgaben';

  @override
  String get exportMenuItem => 'Export';

  @override
  String get templatesMenuItem => 'Vorlagen';

  @override
  String get paymentsMenuItem => 'Zahlungen';

  @override
  String get payrollMenuItem => 'Lohnabrechnung';

  @override
  String get settingsMenuItem => 'Einstellungen';

  @override
  String get geofencesMenuItem => 'Geofences';

  @override
  String get datevMenuItem => 'DATEV';

  @override
  String get blacklistMenuItem => 'Sperrliste';

  @override
  String get emergencyMenuItem => 'Notfall';

  @override
  String get ridePoolsMenuItem => 'Fahrgemeinschaften';

  @override
  String get notificationsMenuItem => 'Benachrichtigungen';

  @override
  String get gdprMenuItem => 'Datenschutz';

  @override
  String get sessionsMenuItem => 'Sitzungen';

  @override
  String get schedVisibilityMenuItem => 'Terminplan-Sichtbarkeit';

  @override
  String get analyticsMenuItem => 'Analysen';

  @override
  String get driverBoardMenuItem => 'Fahrerbrett';

  @override
  String get driverMapMenuItem => 'Fahrerkarte';

  @override
  String assignRideDialogTitle(String rideId) {
    return 'Fahrt #$rideId zuweisen';
  }

  @override
  String get rideDetailsLabel => 'Fahrtdetails';

  @override
  String get clientLabel => 'Kunde';

  @override
  String get timeLabel => 'Uhrzeit';

  @override
  String get fromLabel => 'Von';

  @override
  String get toLabel => 'Nach';

  @override
  String get flightLabel => 'Flug';

  @override
  String get fareLabel => 'Fahrpreis';

  @override
  String get assigningToLabel => 'Zuweisen an';

  @override
  String scheduleConflictsCount(int count) {
    return 'Terminüberschneidungen ($count)';
  }

  @override
  String get assignDriverButton => 'Fahrer zuweisen';

  @override
  String reassignRideDialogTitle(String rideId) {
    return 'Fahrt #$rideId neu zuweisen';
  }

  @override
  String get nearestAvailableDriversLabel =>
      'NÄCHSTE VERFÜGBARE FAHRER · NACH ETA SORTIERT';

  @override
  String get noDriversAvailableForReassignment =>
      'Keine anderen Fahrer für die Neuzuweisung verfügbar.';

  @override
  String reassignNRides(int count) {
    return '$count Fahrt(en) neu zuweisen';
  }

  @override
  String driverDelayedMessage(String driverName, String slack) {
    return '$driverName hat Verspätung — Puffer $slack min';
  }

  @override
  String ridesToReassignLabel(int selected, int total) {
    return 'Fahrten zur Neuzuweisung ($selected/$total)';
  }

  @override
  String get deselectAllButton => 'Alle abwählen';

  @override
  String get selectAllButton => 'Alle auswählen';

  @override
  String get bestMatchBadge => 'Beste Übereinstimmung';

  @override
  String get stillLateLabel => 'noch zu spät';

  @override
  String get slackRestoredLabel => 'Puffer wiederhergestellt';

  @override
  String get tightLabel => 'knapp';

  @override
  String ridesReassignedMessage(int count, String driverName) {
    return '$count Fahrt(en) wurden $driverName neu zugewiesen';
  }

  @override
  String get reassignAnyway => 'Trotzdem neu zuweisen';

  @override
  String get pendingTab => 'Ausstehend';

  @override
  String get assignedTab => 'Zugewiesen';

  @override
  String get sortTooltip => 'Sortieren';

  @override
  String get noAssignedRides => 'Keine zugewiesenen Fahrten';

  @override
  String get noRidesCurrentlyAssigned =>
      'Derzeit keine Fahrten den Fahrern zugewiesen';

  @override
  String get pendingRequestsHeader => 'Ausstehende Anfragen';

  @override
  String unassignedRidesBadge(int count) {
    return '$count nicht zugewiesen';
  }

  @override
  String get rideAtRiskTitle => 'Fahrt mit Verspätungsrisiko';

  @override
  String get etaMonitorBadgeLabel => 'PRÄDIKTIVE ETA-ÜBERWACHUNG · 60S';

  @override
  String get viewButton => 'Anzeigen';

  @override
  String get etaDriverEtaLabel => 'FAHRER ETA';

  @override
  String get etaPickupInLabel => 'ABHOLUNG IN';

  @override
  String get etaSlackLabel => 'PUFFER';

  @override
  String get driverEarningsTitle => 'Fahrereinnahmen';

  @override
  String get sortByEarnings => 'Nach Einnahmen sortieren';

  @override
  String get sortByName => 'Nach Name sortieren';

  @override
  String get sortByRides => 'Nach Fahrten sortieren';

  @override
  String get driverPayrollTitle => 'Fahrerlohnabrechnung';

  @override
  String get payrollSummaryTitle => 'Gehaltsübersicht';

  @override
  String get loadPayrollButton => 'Lohnabrechnung laden';

  @override
  String get payrollCsvCopiedMessage => 'Gehalts-CSV in Zwischenablage kopiert';

  @override
  String get commissionLabel => 'Provision: ';

  @override
  String get rideStatusHandedOff => 'Übergeben';

  @override
  String get handOffRide => 'Fahrt übergeben';

  @override
  String get handOffRideTitle => 'Fahrt übergeben';

  @override
  String get handOffPartnerCompany => 'Partnerunternehmen';

  @override
  String get handOffExternalDriver => 'Externer Fahrer';

  @override
  String get handOffSelectCompany => 'Unternehmen auswählen';

  @override
  String get handOffSelectDriver => 'Fahrer auswählen';

  @override
  String get handOffAddNewCompany => '+ Neues Unternehmen hinzufügen';

  @override
  String get handOffAddNewDriver => '+ Neuen Fahrer hinzufügen';

  @override
  String get handOffCompanyName => 'Unternehmensname *';

  @override
  String get handOffDriverName => 'Fahrername *';

  @override
  String get handOffPhoneOptional => 'Telefon (optional)';

  @override
  String get handOffButton => 'Übergeben';

  @override
  String get closeRide => 'Schließen';

  @override
  String get closeRideTitle => 'Fahrt schließen?';

  @override
  String get closeRideConfirmMessage =>
      'Dadurch wird die nicht zugewiesene Fahrt storniert. Der Kunde wird benachrichtigt.';

  @override
  String get closeRideButton => 'Fahrt schließen';
}
