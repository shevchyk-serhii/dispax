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
  String get selectDriverToViewSchedule =>
      'Wählen Sie einen Fahrer, um seinen Zeitplan anzuzeigen';

  @override
  String get noScheduleForDriver => 'Keine Zeitplaneinträge für diesen Fahrer';

  @override
  String get noPendingRides => 'Keine ausstehenden Fahrten';

  @override
  String get rideAlreadyAssignedInfo =>
      'Diese Fahrt wurde bereits zugewiesen. Die Liste wurde aktualisiert.';

  @override
  String get allRidesAssigned => 'Alle Fahrten wurden zugewiesen';

  @override
  String get selectDriver => 'Fahrer auswählen';

  @override
  String get reassignDriver => 'Fahrer neu zuweisen';

  @override
  String get noDriversFound => 'Keine Fahrer gefunden';

  @override
  String get reassignRide => 'Fahrt neu zuweisen';

  @override
  String get confirmReassignment => 'Neuzuweisung bestätigen';

  @override
  String get reassign => 'Neu zuweisen';

  @override
  String get assign => 'Zuweisen';

  @override
  String get driverDashboardTitle => 'Fahrer-Dashboard';

  @override
  String get secretaryDashboardTitle => 'Sekretariat-Dashboard';

  @override
  String get dispatcherDashboardTitle => 'Dispatcher-Dashboard';

  @override
  String get adminDashboardTitle => 'Admin-Dashboard';

  @override
  String get platformAdminTitle => 'Plattform-Admin';

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
  String get passwordPolicyRules =>
      'Das Passwort muss mindestens 8 Zeichen lang sein und einen Großbuchstaben, einen Kleinbuchstaben und eine Ziffer enthalten';

  @override
  String get forcePasswordChangeTitle => 'Neues Passwort festlegen';

  @override
  String get forcePasswordChangeMessage =>
      'Ihr Konto verwendet ein temporäres Passwort. Bitte legen Sie ein neues Passwort fest, um fortzufahren.';

  @override
  String get updateRequired => 'Aktualisierung erforderlich';

  @override
  String get updateRequiredMessage =>
      'Diese Version der App wird nicht mehr unterstützt. Bitte aktualisieren Sie auf die neueste Version, um fortzufahren.';

  @override
  String get updateNow => 'Jetzt aktualisieren';

  @override
  String get temporaryPassword => 'Temporäres Passwort';

  @override
  String get temporaryPasswordHint =>
      'Der Benutzer wird beim ersten Anmelden aufgefordert, es zu ändern.';

  @override
  String get tempPasswordRules =>
      'Mindestens 8 Zeichen mit Großbuchstabe, Kleinbuchstabe und Ziffer';

  @override
  String get setNewPassword => 'Neues Passwort festlegen';

  @override
  String get userCreatedSharePassword =>
      'Benutzer erstellt. Teilen Sie ihm das temporäre Passwort mit.';

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
  String get english => 'Englisch';

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
  String get appVersion => 'App-Version';

  @override
  String get backendVersion => 'Backend-Version';

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
  String passengerCheckpointStatus(String checkpoint) {
    return 'Passagier: $checkpoint';
  }

  @override
  String get markCheckpointButton => 'Ich bin hier';

  @override
  String get airportCheckpointPanelTitle => 'Mein Standort im Terminal';

  @override
  String get airportEntryTitle => 'Terminal-Einfahrtszeit';

  @override
  String get airportDepartIn => 'Losfahren in:';

  @override
  String get airportEntryLabel => 'Terminal-Einfahrt:';

  @override
  String airportEntryAt(String time) {
    return 'Einfahrt um $time';
  }

  @override
  String airportLandingAt(String time) {
    return 'Landung um $time';
  }

  @override
  String airportLandedAt(String time) {
    return 'Gelandet um $time';
  }

  @override
  String airportFlightDelay(int minutes) {
    return '+$minutes Min. Verspätung';
  }

  @override
  String airportScheduledVsActual(String scheduled, String actual) {
    return 'Planmäßig $scheduled → $actual';
  }

  @override
  String get airportTravelTime => 'Fahrzeit:';

  @override
  String airportParkingSavings(String amount) {
    return 'Parkersparnis: $amount';
  }

  @override
  String get airportDepartNow => 'Jetzt losfahren!';

  @override
  String get airportFlightDelayed =>
      'Flug verspätet. Einfahrtszeit neu berechnet.';

  @override
  String airportTimingError(String error) {
    return 'Fehler beim Laden der Daten: $error';
  }

  @override
  String get airportLoadingTiming => 'Einfahrtszeit wird geladen...';

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
  String get addressNotFound =>
      'Adresse konnte nicht gefunden werden — bitte Schreibweise prüfen.';

  @override
  String addressOutOfServiceArea(int distanceKm, int radiusKm) {
    return 'Adresse liegt außerhalb des Servicegebiets (etwa $distanceKm km von München, max. $radiusKm km).';
  }

  @override
  String addressOutOfServiceAreaShort(int radiusKm) {
    return 'Adresse liegt außerhalb des Servicegebiets (max. $radiusKm km von München).';
  }

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
  String get moreActions => 'Weitere Aktionen';

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
  String get companyVatIdLabel => 'USt-IdNr.';

  @override
  String get invoiceLanguageLabel => 'Rechnungssprache';

  @override
  String get languageStandard => 'Standard';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'Englisch';

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
  String get invoicesRailLabel => 'Rechnungen';

  @override
  String get clientsRailLabel => 'Kunden';

  @override
  String get datevRailLabel => 'DATEV';

  @override
  String genericError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get errorNetwork =>
      'Server nicht erreichbar. Bitte prüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.';

  @override
  String get errorTimeout =>
      'Der Server hat zu lange gebraucht. Bitte versuchen Sie es erneut.';

  @override
  String get errorServer =>
      'Auf unserer Seite ist etwas schiefgelaufen. Bitte versuchen Sie es gleich noch einmal.';

  @override
  String get errorNotFound =>
      'Wir konnten nicht finden, wonach Sie gesucht haben.';

  @override
  String get errorLoadingData => 'Daten konnten nicht geladen werden';

  @override
  String get errorGeneric =>
      'Etwas ist schiefgelaufen. Bitte versuchen Sie es erneut.';

  @override
  String get errorSessionExpired =>
      'Ihre Sitzung ist abgelaufen. Bitte melden Sie sich erneut an.';

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
  String get vatPercentLabel => 'MwSt. %';

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
    return 'Quittungsfehler: $error';
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
  String get viewRideOnMap => 'Auf Karte anzeigen';

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
  String get refreshFlightStatus => 'Flugstatus aktualisieren';

  @override
  String get flightStatusRefreshed => 'Flugstatus aktualisiert';

  @override
  String get flightStatusUnchanged => 'Bereits aktuell';

  @override
  String get flightNotFoundYet => 'Flug noch nicht im System';

  @override
  String get failedToRefreshFlightStatus =>
      'Flugstatus konnte nicht aktualisiert werden';

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
  String get pickupSignMenuItem => 'Abholschild';

  @override
  String get pickupSignTitle => 'Abholschild';

  @override
  String get pickupSignHint => 'Name oder Text eingeben…';

  @override
  String get pickupSignShowButton => 'Anzeigen';

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
  String assignRideDialogTitle(String client) {
    return 'Fahrt zuweisen · $client';
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
  String reassignRideDialogTitle(String client) {
    return 'Fahrt neu zuweisen · $client';
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
    return '$driverName hat Verspätung — Puffer $slack Min.';
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
      'Derzeit sind keine Fahrten Fahrern zugewiesen';

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
  String get payrollCsvCopiedMessage =>
      'Gehalts-CSV in die Zwischenablage kopiert';

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
  String get rideHandedOffInfo => 'Fahrt an den externen Partner übergeben.';

  @override
  String handOffFailed(String message) {
    return 'Übergabe fehlgeschlagen: $message';
  }

  @override
  String get closeRide => 'Schließen';

  @override
  String get closeRideTitle => 'Fahrt schließen?';

  @override
  String get closeRideConfirmMessage =>
      'Dadurch wird die nicht zugewiesene Fahrt storniert. Der Kunde wird benachrichtigt.';

  @override
  String get closeRideButton => 'Fahrt schließen';

  @override
  String get confirmRide => 'Fahrt bestätigen';

  @override
  String get rejectRide => 'Fahrt ablehnen';

  @override
  String get rejectReasonPrompt => 'Grund für die Ablehnung';

  @override
  String get rejectButton => 'Ablehnen';

  @override
  String get rejectReasonTooFar => 'Abholung zu weit entfernt';

  @override
  String get rejectReasonBusy => 'Mit einer anderen Fahrt beschäftigt';

  @override
  String get rejectReasonBreak => 'Pause / Schichtende';

  @override
  String get rejectReasonVehicleIssue => 'Fahrzeugproblem';

  @override
  String get rejectReasonOther => 'Sonstiges';

  @override
  String get rideConfirmed => 'Fahrt bestätigt';

  @override
  String get rideRejected => 'Fahrt abgelehnt';

  @override
  String get confirmationRequestTitle => 'Fahrtbestätigung erforderlich';

  @override
  String get confirmationRequestBody =>
      'Bitte bestätigen Sie Ihre zugewiesene Fahrt oder lehnen Sie sie ab';

  @override
  String get statusConfirmed => 'Bestätigt';

  @override
  String get ridesTab => 'Fahrten';

  @override
  String get createTab => 'Erstellen';

  @override
  String get frontDeskTitle => 'Empfang';

  @override
  String get quickBook => 'Schnellbuchung';

  @override
  String get bookedToday => 'Heute gebucht';

  @override
  String get awaitingConfirm => 'Wartet auf Bestätigung';

  @override
  String get activeClientsLabel => 'Aktive Kunden';

  @override
  String get templatesLabel => 'Vorlagen';

  @override
  String get todaysBookings => 'Heutige Buchungen';

  @override
  String get noRidesToday => 'Keine Fahrten heute';

  @override
  String get loadRidesToSeeBookings =>
      'Fahrten laden, um heutige Buchungen zu sehen';

  @override
  String get manageClientsTitle => 'Kunden verwalten';

  @override
  String get searchClientsHint => 'Kunden suchen...';

  @override
  String get noClientsMatchSearch => 'Keine Kunden entsprechen Ihrer Suche';

  @override
  String get noClientsYet => 'Noch keine Kunden';

  @override
  String get addClientTitle => 'Kunde hinzufügen';

  @override
  String get phoneOptional => 'Telefon (optional)';

  @override
  String get nameRequired => 'Name ist erforderlich';

  @override
  String get emailRequired => 'E-Mail ist erforderlich';

  @override
  String get invalidEmail => 'Ungültige E-Mail';

  @override
  String get addButton => 'Hinzufügen';

  @override
  String get editAction => 'Bearbeiten';

  @override
  String get duplicateRideAction => 'Duplizieren';

  @override
  String get deactivateAction => 'Deaktivieren';

  @override
  String get editClientTitle => 'Kunde bearbeiten';

  @override
  String get clientUpdatedSuccess => 'Kunde erfolgreich aktualisiert';

  @override
  String get clientUpdateFailed =>
      'Kunde konnte nicht aktualisiert werden. Bitte erneut versuchen.';

  @override
  String get deactivateClientTitle => 'Kunde deaktivieren';

  @override
  String deactivateClientConfirmMsg(String name) {
    return 'Möchten Sie $name wirklich deaktivieren?';
  }

  @override
  String get newRideButton => 'Neue Fahrt';

  @override
  String get ridesCountLabel => 'Fahrten';

  @override
  String get preferredDriverAssigned => 'Bevorzugter Fahrer zugewiesen';

  @override
  String get noRidesYet => 'Noch keine Fahrten';

  @override
  String get clientCompanyFieldLabel => 'Unternehmen';

  @override
  String get clientCompanyNone => 'Kein Unternehmen';

  @override
  String get vipClientLabel => 'VIP-Kunde';

  @override
  String get vipClientHelpText => 'Prioritätsservice und bevorzugter Fahrer';

  @override
  String driverLabel(String name) {
    return 'Fahrer: $name';
  }

  @override
  String get reportsTitle => 'Berichte';

  @override
  String get totalRidesLabel => 'Fahrten gesamt';

  @override
  String get inProgressLabel => 'In Bearbeitung';

  @override
  String get requestedLabel => 'Angefordert';

  @override
  String get assignedLabel => 'Zugewiesen';

  @override
  String get keyMetrics => 'Kennzahlen';

  @override
  String get cancellationRateLabel => 'Stornierungsrate';

  @override
  String get statusBreakdown => 'Statusaufschlüsselung';

  @override
  String get noRideDataYet => 'Noch keine Fahrtdaten';

  @override
  String get noActiveRides => 'Sie haben keine aktiven Fahrten';

  @override
  String get useBookTabHint =>
      'Verwenden Sie den Tab \"Buchen\", um eine zu erstellen';

  @override
  String get trackDriver => 'Fahrer verfolgen';

  @override
  String departureTimeReachedFlight(String flightInfo) {
    return 'Abflugzeit für Flug $flightInfo erreicht';
  }

  @override
  String failedToCancelRide(String error) {
    return 'Fehler beim Stornieren: $error';
  }

  @override
  String get failedToLoadRides => 'Fahrten konnten nicht geladen werden';

  @override
  String get goodMorning => 'Guten Morgen,';

  @override
  String get goodAfternoon => 'Guten Tag,';

  @override
  String get goodEvening => 'Guten Abend,';

  @override
  String get whereTo => 'Wohin?';

  @override
  String get onTrip => 'Auf Fahrt';

  @override
  String get driverOnTheWay => 'Fahrer unterwegs';

  @override
  String get driverAssigned => 'Fahrer zugewiesen';

  @override
  String get yourDriver => 'Ihr Fahrer';

  @override
  String get savedPlaces => 'GESPEICHERTE ORTE';

  @override
  String get savedPlaceHome => 'Zuhause';

  @override
  String get savedPlaceOffice => 'Büro';

  @override
  String get addAddress => 'Adresse hinzufügen';

  @override
  String get useThisAddress => 'Diese Adresse verwenden';

  @override
  String get editAddress => 'Adresse bearbeiten';

  @override
  String get removeAddress => 'Entfernen';

  @override
  String get removeAddressConfirm => 'Diesen gespeicherten Ort entfernen?';

  @override
  String get myAddresses => 'MEINE ADRESSEN';

  @override
  String get manageAddresses => 'Gespeicherte Adressen';

  @override
  String get addCustomAddress => 'Neuen Ort hinzufügen';

  @override
  String get addressLabel => 'Bezeichnung';

  @override
  String get addressLabelHint => 'z. B. Fitnessstudio, Eltern';

  @override
  String get labelRequired => 'Bitte eine Bezeichnung eingeben';

  @override
  String get bookARide => 'Fahrt buchen';

  @override
  String get scheduled => 'GEPLANT';

  @override
  String get nowLabel => 'JETZT';

  @override
  String get asap => 'BALDMÖGLICHST';

  @override
  String get vehicleClass => 'FAHRZEUGKLASSE';

  @override
  String get estimatedTotal => 'Geschätzter Gesamtpreis';

  @override
  String get estimateUnavailableHint =>
      'Für diese Adresse konnte kein Preis ermittelt werden. Sie können trotzdem buchen — der Fahrpreis wird nachträglich bestätigt.';

  @override
  String get confirmBooking => 'Buchung bestätigen';

  @override
  String get rideBookedSuccessfully => 'Fahrt erfolgreich gebucht!';

  @override
  String get failedToCreateRide => 'Fehler beim Erstellen der Fahrt';

  @override
  String get failedToLoadRideHistory =>
      'Fahrtenverlauf konnte nicht geladen werden';

  @override
  String get listView => 'Liste';

  @override
  String get pastLabel => 'VERGANGEN';

  @override
  String get confirmedStatus => 'Bestätigt';

  @override
  String get rateThisRide => 'Fahrt bewerten';

  @override
  String get thankYouForRating => 'Danke für Ihre Bewertung!';

  @override
  String failedToSubmitRating(String error) {
    return 'Fehler beim Absenden der Bewertung: $error';
  }

  @override
  String rideCardTimeLabel(String time) {
    return 'Zeit: $time';
  }

  @override
  String get deleteConfirmationTitle => 'Bestätigung';

  @override
  String deleteRideConfirmMessage(String from, String to) {
    return 'Fahrt $from → $to löschen?';
  }

  @override
  String get cancelRideDialogTitle => 'Fahrt stornieren';

  @override
  String get selectCancellationReason =>
      'Bitte wählen Sie einen Stornierungsgrund:';

  @override
  String get cancellationReasonLabel => 'Grund';

  @override
  String get cancellationReasonClientRequest => 'Kundenwunsch';

  @override
  String get cancellationReasonWeather => 'Wetter';

  @override
  String get cancellationReasonOther => 'Sonstiges';

  @override
  String get cancellationReasonClientNoShow => 'Kunde nicht erschienen';

  @override
  String get cancellationReasonDriverUnavailable => 'Fahrer nicht verfügbar';

  @override
  String get cancellationReasonVehicleIssue => 'Fahrzeugproblem';

  @override
  String get cancellationFeeLabel => 'Stornogebühr (optional)';

  @override
  String get rateRideExperienceQuestion => 'Wie war Ihre Erfahrung?';

  @override
  String get rateRideCommentLabel => 'Kommentar (optional)';

  @override
  String get rateRideCommentHint => 'Erzählen Sie uns von Ihrer Erfahrung...';

  @override
  String get airportTransferLabel => 'Flughafentransfer';

  @override
  String get airportTransferHint =>
      'Aktivieren, wenn es sich um eine Flughafenabholung/-abgabe handelt';

  @override
  String get airportDepartureLabel => 'Abflug';

  @override
  String get airportDepartureHint => 'Zum Flughafen';

  @override
  String get airportArrivalLabel => 'Ankunft';

  @override
  String get airportArrivalHint => 'Vom Flughafen';

  @override
  String get flightNumberLabel => 'Flugnummer';

  @override
  String get flightNumberHint => 'z.B. LH123, BA456';

  @override
  String get flightNumberRequired => 'Flugnummer ist erforderlich';

  @override
  String get flightNumberInvalidFormat =>
      'Gültige Flugnummer eingeben, z.B. LH429';

  @override
  String get gateLabel => 'Gate';

  @override
  String get terminalLabel => 'Terminal';

  @override
  String get gateRemote => 'Bus-Gate (Außenposition)';

  @override
  String get creatingRideLabel => 'Fahrt wird erstellt...';

  @override
  String get createRideButton => 'Fahrt erstellen';

  @override
  String get clearFormButton => 'Formular leeren';

  @override
  String get vehicleInformationLabel => 'Fahrzeuginformationen';

  @override
  String get messageButton => 'Nachricht';

  @override
  String get routeInformationLabel => 'Routeninformationen';

  @override
  String get pickupTimeLabel => 'Abholzeit';

  @override
  String get distanceLabel => 'Entfernung';

  @override
  String get durationLabel => 'Dauer';

  @override
  String get etaToClientLabel => 'ETA zum Kunden';

  @override
  String get openInGoogleMapsButton => 'In Google Maps öffnen';

  @override
  String get rideStatusLabel => 'Fahrtstatus';

  @override
  String get rideHasBeenCancelledLabel => 'Diese Fahrt wurde storniert';

  @override
  String get rideStatusRequestedClientLabel => 'Warte auf Fahrerzuweisung';

  @override
  String get rideStatusRequestedStaffLabel => 'Warte auf Zuweisung';

  @override
  String get rideStatusAssignedEnRouteLabel => 'Fahrer ist unterwegs';

  @override
  String get rideStatusAssignedLabel => 'Fahrer zugewiesen';

  @override
  String get rideStatusAssignedDriverLabel =>
      'Sie sind dieser Fahrt zugewiesen';

  @override
  String get rideStatusInProgressClientLabel => 'Fahrt läuft';

  @override
  String get rideStatusInProgressDriverLabel => 'Gute Fahrt';

  @override
  String get rideStatusCompletedLabel => 'Erfolgreich abgeschlossen';

  @override
  String get rideStatusCancelledLabel => 'Fahrt storniert';

  @override
  String get rideStatusHandedOffLabel => 'An Partner übergeben';

  @override
  String get rideStatusConfirmedClientLabel =>
      'Fahrer hat Ihre Fahrt bestätigt';

  @override
  String get rideStatusConfirmedDriverLabel =>
      'Sie haben diese Fahrt bestätigt';

  @override
  String get rideStatusConfirmedDriverReadyLabel =>
      'Sie haben diese Fahrt bestätigt — bereit zum Start';

  @override
  String get authenticationRequiredError => 'Authentifizierung erforderlich';

  @override
  String get selectOrCreateClientError =>
      'Bitte wählen oder erstellen Sie einen Kunden';

  @override
  String get enterClientNameError => 'Bitte geben Sie den Kundennamen ein';

  @override
  String get editRideDialogTitle => 'Fahrt bearbeiten';

  @override
  String get pickupDateTimeLabel => 'Abholdatum/-uhrzeit';

  @override
  String get flightNumberOptionalLabel => 'Flugnummer (optional)';

  @override
  String get notesOptionalLabel => 'Notizen (optional)';

  @override
  String serverErrorMessage(String statusCode) {
    return 'Serverfehler: $statusCode';
  }

  @override
  String get useDispatcherDashboardInfo =>
      'Verwenden Sie das Dispatcher-Dashboard, um Fahrer zuzuweisen';

  @override
  String get updateLocationTitle => 'Standort aktualisieren';

  @override
  String get tellDriverWhereYouAreLabel =>
      'Sagen Sie dem Fahrer, wo Sie sich befinden:';

  @override
  String get quickSelectLabel => 'Schnellauswahl:';

  @override
  String get locationQuickMainEntrance => 'Am Haupteingang';

  @override
  String get locationQuickBaggageClaim => 'Am Gepäckband';

  @override
  String get locationQuickCafe => 'Am Café';

  @override
  String get locationQuickParking => 'Am Parkplatz';

  @override
  String get locationQuickInformationDesk => 'Am Informationsschalter';

  @override
  String get locationQuickSecondFloor => 'Im zweiten Stockwerk';

  @override
  String get locationQuickExit1 => 'Am Ausgang Nr. 1';

  @override
  String get locationQuickExit2 => 'Am Ausgang Nr. 2';

  @override
  String get locationQuickOther => 'Anderer Standort';

  @override
  String get orSpecifyExactlyLabel => 'Oder genau angeben:';

  @override
  String get locationExampleHint => 'Beispiel: „Am Terminal-A-Eingang“';

  @override
  String get additionalInstructionsLabel =>
      'Zusätzliche Anweisungen (optional):';

  @override
  String get additionalInstructionsExampleHint => 'Beispiel: „Stehe beim Café“';

  @override
  String get specifyLocationError => 'Bitte geben Sie Ihren Standort an';

  @override
  String get failedToUpdateLocationError =>
      'Standort konnte nicht aktualisiert werden. Bitte versuchen Sie es erneut.';

  @override
  String get callClientTooltip => 'Kunden anrufen';

  @override
  String get navigateTooltip => 'Navigieren';

  @override
  String get delayByHowLongTitle => 'Wie lange verzögern?';

  @override
  String minutesLabel(int minutes) {
    return '$minutes Minuten';
  }

  @override
  String get appSubtitle => 'Intelligente Mobilitätslösungen';

  @override
  String get orLabel => 'oder';

  @override
  String get touchIdLabel => 'Touch ID';

  @override
  String get biometricsLabel => 'Biometrie';

  @override
  String get biometricSetupTitle => 'Biometrische Einrichtung';

  @override
  String get biometricSetupMessage =>
      'Möchten Sie die schnelle Anmeldung per Biometrie aktivieren?\n\nDamit können Sie sich per Face ID, Touch ID oder Fingerabdruck anmelden.';

  @override
  String get laterButton => 'Später';

  @override
  String get enableButton => 'Aktivieren';

  @override
  String get createButton => 'Erstellen';

  @override
  String get allLabel => 'Alle';

  @override
  String get statusLabel => 'Status';

  @override
  String operationFailed(String error) {
    return 'Fehler: $error';
  }

  @override
  String get roleLabel => 'Rolle';

  @override
  String get addGeofenceTooltip => 'Geofence hinzufügen';

  @override
  String get savedTemplatesTitle => 'Gespeicherte Vorlagen';

  @override
  String get createTemplateDialogTitle => 'Vorlage erstellen';

  @override
  String get templateNameLabel => 'Vorlagenname';

  @override
  String get fromAddressLabel => 'Abfahrtsadresse';

  @override
  String get toAddressLabel => 'Zieladresse';

  @override
  String get templatePickupTimeLabel => 'Abholzeit (HH:mm)';

  @override
  String get recurrenceLabel => 'Wiederholung';

  @override
  String get recurrenceDaily => 'Täglich';

  @override
  String get recurrenceWeekdays => 'Wochentags';

  @override
  String get recurrenceWeeklyMonday => 'Wöchentlich Montag';

  @override
  String get recurrenceWeeklyTuesday => 'Wöchentlich Dienstag';

  @override
  String get recurrenceWeeklyWednesday => 'Wöchentlich Mittwoch';

  @override
  String get recurrenceWeeklyThursday => 'Wöchentlich Donnerstag';

  @override
  String get recurrenceWeeklyFriday => 'Wöchentlich Freitag';

  @override
  String get recurrenceSaturdayLabel => 'Wöchentlich Samstag';

  @override
  String get recurrenceSundayLabel => 'Wöchentlich Sonntag';

  @override
  String get priceOptionalLabel => 'Preis (optional)';

  @override
  String get generateRidesMenuLabel => 'Fahrten generieren';

  @override
  String get deactivateTemplateMenuLabel => 'Deaktivieren';

  @override
  String get noTemplatesYet => 'Noch keine Vorlagen';

  @override
  String get noTemplatesSubtitle =>
      'Erstellen Sie eine Vorlage für wiederkehrende Fahrten';

  @override
  String get addTemplateButton => 'Vorlage hinzufügen';

  @override
  String get ridesGeneratedSuccess => 'Fahrten erfolgreich generiert';

  @override
  String failedToGenerateRides(String error) {
    return 'Fehler beim Generieren: $error';
  }

  @override
  String failedToDeactivateTemplate(String error) {
    return 'Fehler beim Deaktivieren: $error';
  }

  @override
  String get templateBadgeActive => 'Aktiv';

  @override
  String get templateBadgePaused => 'Pausiert';

  @override
  String get geofenceScreenTitle => 'Geofences';

  @override
  String get zonesTabLabel => 'Zonen';

  @override
  String get recentAlertsTabLabel => 'Aktuelle Alarme';

  @override
  String get createGeofenceDialogTitle => 'Geofence erstellen';

  @override
  String get zoneNameLabel => 'Zonenname';

  @override
  String get geofenceTypeLabel => 'Typ';

  @override
  String get geofenceTypeServiceArea => 'Servicegebiet';

  @override
  String get geofenceTypeClientPickup => 'Kundenabholung';

  @override
  String get geofenceTypeCustomZone => 'Benutzerdefinierte Zone';

  @override
  String get latitudeLabel => 'Breitengrad';

  @override
  String get longitudeLabel => 'Längengrad';

  @override
  String get radiusLabel => 'Radius';

  @override
  String get notifyOnEntryLabel => 'Benachrichtigung bei Einfahrt';

  @override
  String get notifyOnExitLabel => 'Benachrichtigung bei Ausfahrt';

  @override
  String get noGeofenceZonesYet => 'Noch keine Geofence-Zonen';

  @override
  String get createZonesToMonitorSubtitle =>
      'Erstellen Sie Zonen zur Überwachung von Ein- und Ausfahrten';

  @override
  String get createZoneButton => 'Zone erstellen';

  @override
  String get deleteZoneConfirmTitle => 'Zone löschen';

  @override
  String deleteZoneConfirmMsg(String name) {
    return '\"$name\" löschen?';
  }

  @override
  String get geofenceDeletedSuccess => 'Geofence gelöscht';

  @override
  String failedToDeleteGeofence(String error) {
    return 'Fehler beim Löschen: $error';
  }

  @override
  String failedToToggleGeofence(String code) {
    return 'Fehler beim Umschalten ($code)';
  }

  @override
  String failedToCreateGeofence(String code) {
    return 'Fehler beim Erstellen ($code)';
  }

  @override
  String get geofenceCreatedSuccess => 'Geofence erstellt';

  @override
  String get fillRequiredFieldsError => 'Bitte alle Pflichtfelder ausfüllen';

  @override
  String get noAlertsFound => 'Keine Alarme gefunden';

  @override
  String driverEnteredGeofence(String geofenceName) {
    return 'Fahrer hat $geofenceName betreten';
  }

  @override
  String driverLeftGeofence(String geofenceName) {
    return 'Fahrer hat $geofenceName verlassen';
  }

  @override
  String get alertFilterAll => 'Alle';

  @override
  String get alertFilterEntry => 'Einfahrt';

  @override
  String get alertFilterExit => 'Ausfahrt';

  @override
  String get alertFilterLabel => 'Filter:';

  @override
  String geofenceSubtitleAirport(int radius) {
    return 'Flughafen-Zone · ${radius}m Radius';
  }

  @override
  String geofenceSubtitleServiceArea(int radius) {
    return 'Servicegebiet · ${radius}m Radius';
  }

  @override
  String geofenceSubtitleClientPickup(int radius) {
    return 'Kundenabholpunkt · ${radius}m Radius';
  }

  @override
  String geofenceSubtitleCustomZone(int radius) {
    return 'Benutzerdefinierte Zone · ${radius}m Radius';
  }

  @override
  String failedToLoadGeofences(String code) {
    return 'Fehler beim Laden ($code)';
  }

  @override
  String failedToLoadAlerts(String code) {
    return 'Fehler beim Laden der Alarme ($code)';
  }

  @override
  String get notifTabNotifications => 'Benachrichtigungen';

  @override
  String get notifTabSettings => 'Einstellungen';

  @override
  String get markAllReadButton => 'Alle als gelesen markieren';

  @override
  String get clearAllNotificationsMenuLabel => 'Alle löschen';

  @override
  String get clearAllConfirmTitle => 'Alle Benachrichtigungen löschen';

  @override
  String get clearAllConfirmContent =>
      'Möchten Sie wirklich alle Benachrichtigungen löschen?';

  @override
  String get deleteAllNotificationsButton => 'Alle löschen';

  @override
  String get noNotificationsYet => 'Keine Benachrichtigungen';

  @override
  String get notifFilterAll => 'Alle';

  @override
  String get notifFilterRides => 'Fahrten';

  @override
  String get notifFilterChat => 'Chat';

  @override
  String get notifFilterGeofence => 'Geofence';

  @override
  String get notifFilterPools => 'Pools';

  @override
  String get notifFilterCheckpoints => 'Checkpoints';

  @override
  String get notifJustNow => 'Gerade eben';

  @override
  String notifMinutesAgo(int count) {
    return 'vor $count Min.';
  }

  @override
  String notifHoursAgo(int count) {
    return 'vor $count Std.';
  }

  @override
  String notifDaysAgo(int count) {
    return 'vor $count Tagen';
  }

  @override
  String get notifPrefSectionPush => 'Push-Benachrichtigungen';

  @override
  String get notifPrefSectionAdditional => 'Weitere Kanäle';

  @override
  String get notifPrefRideUpdatesSubtitle => 'Statusänderungen, Zuweisungen';

  @override
  String get notifPrefChatMessagesSubtitle =>
      'Neue Nachrichten von Fahrer/Kunde';

  @override
  String get notifPrefDriverApproachingLabel => 'Fahrer nähert sich';

  @override
  String get notifPrefDriverApproachingSubtitle =>
      'Wenn der Fahrer in der Nähe der Abholung ist';

  @override
  String get notifPrefGeofenceAlertsLabel => 'Geofence-Alarme';

  @override
  String get notifPrefGeofenceAlertsSubtitle => 'Ein-/Ausfahrtalarme';

  @override
  String get notifPrefPoolUpdatesLabel => 'Pool-Updates';

  @override
  String get notifPrefPoolUpdatesSubtitle =>
      'Fahrgemeinschafts-Benachrichtigungen';

  @override
  String get notifPrefEmailLabel => 'E-Mail-Benachrichtigungen';

  @override
  String get notifPrefEmailSubtitle => 'Benachrichtigungen per E-Mail erhalten';

  @override
  String get notifPrefSmsLabel => 'SMS-Benachrichtigungen';

  @override
  String get notifPrefSmsSubtitle => 'Benachrichtigungen per SMS erhalten';

  @override
  String get notifPrefQuietHours => 'Ruhezeiten';

  @override
  String get notifPrefQuietHoursFrom => 'Von';

  @override
  String get notifPrefQuietHoursTo => 'Bis';

  @override
  String get notifPrefNotSet => 'Nicht gesetzt';

  @override
  String get savePreferencesButton => 'Einstellungen speichern';

  @override
  String get preferencesSaved => 'Einstellungen gespeichert';

  @override
  String get revokeSessionDialogTitle => 'Sitzung widerrufen';

  @override
  String get revokeSessionDialogContent =>
      'Das mit dieser Sitzung verbundene Gerät wird abgemeldet.';

  @override
  String get revokeSessionButton => 'Widerrufen';

  @override
  String get revokeAllOtherSessionsDialogTitle =>
      'Alle anderen Sitzungen widerrufen';

  @override
  String get revokeAllOtherSessionsDialogContent =>
      'Alle anderen Geräte werden abgemeldet. Nur Ihre aktuelle Sitzung bleibt aktiv.';

  @override
  String get revokeAllButton => 'Alle widerrufen';

  @override
  String get sessionRevoked => 'Sitzung widerrufen';

  @override
  String get allOtherSessionsRevoked => 'Alle anderen Sitzungen widerrufen';

  @override
  String get noActiveSessions => 'Keine aktiven Sitzungen';

  @override
  String get sessionCurrentLabel => 'Aktuell';

  @override
  String sessionIpLabel(String ip) {
    return 'IP: $ip';
  }

  @override
  String sessionCreatedLabel(String date) {
    return 'Erstellt: $date';
  }

  @override
  String sessionLastActiveLabel(String date) {
    return 'Zuletzt aktiv: $date';
  }

  @override
  String get revokeSessionAction => 'Widerrufen';

  @override
  String get userManagementTitle => 'Benutzerverwaltung';

  @override
  String get createUserDialogTitle => 'Benutzer erstellen';

  @override
  String get searchUsersHint => 'Benutzer suchen...';

  @override
  String get changeRoleMenuHeader => 'Rolle ändern';

  @override
  String get changeStatusMenuHeader => 'Status ändern';

  @override
  String get activateUserAction => 'Aktivieren';

  @override
  String get suspendUserAction => 'Sperren';

  @override
  String get deactivateUserAction => 'Deaktivieren';

  @override
  String get noUsersFound => 'Keine Benutzer gefunden';

  @override
  String get totalUsersLabel => 'Gesamt';

  @override
  String get driversStatLabel => 'Fahrer';

  @override
  String get clientsStatLabel => 'Kunden';

  @override
  String get staffStatLabel => 'Personal';

  @override
  String roleChangedSuccess(String role) {
    return 'Rolle geändert zu $role';
  }

  @override
  String statusChangedSuccess(String status) {
    return 'Status geändert zu $status';
  }

  @override
  String failedToChangeRole(String error) {
    return 'Fehler: $error';
  }

  @override
  String failedToChangeStatus(String error) {
    return 'Fehler: $error';
  }

  @override
  String failedToCreateUser(String error) {
    return 'Fehler: $error';
  }

  @override
  String get blacklistTitle => 'Sperrliste';

  @override
  String get addBlacklistEntryDialogTitle => 'Eintrag hinzufügen';

  @override
  String get clientIdLabel => 'Kunden-ID';

  @override
  String get driverIdLabel => 'Fahrer-ID';

  @override
  String get reasonOptionalLabel => 'Grund (optional)';

  @override
  String get clientDriverIdRequired =>
      'Kunden-ID und Fahrer-ID sind erforderlich';

  @override
  String get removeBlacklistEntryDialogTitle => 'Eintrag entfernen';

  @override
  String get removeBlacklistEntryContent =>
      'Möchten Sie diesen Eintrag wirklich entfernen?';

  @override
  String get removeBlacklistEntryButton => 'Entfernen';

  @override
  String get noBlacklistEntries => 'Keine Einträge in der Sperrliste';

  @override
  String get tenantsTitle => 'Mandanten';

  @override
  String tenantsWithCount(int count) {
    return 'Mandanten · $count Unternehmen';
  }

  @override
  String get onboardButton => '+ Onboarding';

  @override
  String get noTenantsFound => 'Keine Mandanten gefunden';

  @override
  String get onboardCompanyDialogTitle => 'Unternehmen aufnehmen';

  @override
  String get editCompanyDialogTitle => 'Unternehmen bearbeiten';

  @override
  String get subscriptionPlanLabel => 'Abonnementplan';

  @override
  String get colHeaderCompany => 'UNTERNEHMEN';

  @override
  String get colHeaderPlan => 'PLAN';

  @override
  String get colHeaderDrivers => 'FAHRER';

  @override
  String get colHeaderRidesPerMonth => 'FAHRTEN / MON.';

  @override
  String get colHeaderStatus => 'STATUS';

  @override
  String get deactivateCompanyDialogTitle => 'Unternehmen deaktivieren?';

  @override
  String deactivateCompanyDialogContent(String name) {
    return 'Möchten Sie \"$name\" wirklich deaktivieren?\n\nDas Unternehmen wird als Inaktiv markiert, alle Daten (Fahrten, Rechnungen, Benutzer) bleiben erhalten.';
  }

  @override
  String get setActiveAction => 'Aktiv setzen';

  @override
  String get setTrialAction => 'Testphase setzen';

  @override
  String get suspendAction => 'Sperren';

  @override
  String get emergencyReassignmentTitle => 'Notfall-Umbesetzungen';

  @override
  String get emergencyReassignmentDialogTitle => 'Notfall-Umbesetzung';

  @override
  String get rideIdLabel => 'Fahrt-ID';

  @override
  String get emergencyReasonLabel => 'Grund';

  @override
  String get availableDriversLabel => 'Verfügbare Fahrer:';

  @override
  String get newDriverIdLabel => 'Neue Fahrer-ID (optional)';

  @override
  String get newDriverIdHelper => 'Leer lassen, um Zuweisung aufzuheben';

  @override
  String get reassignButton => 'Neu zuweisen';

  @override
  String get rideIdRequired => 'Fahrt-ID ist erforderlich';

  @override
  String get emergencyReassignmentCreated => 'Notfall-Umbesetzung erstellt';

  @override
  String get noEmergencyReassignments => 'Keine Notfall-Umbesetzungen';

  @override
  String get emergencyReasonDriverIllness => 'Fahrerkrankheit';

  @override
  String get emergencyReasonVehicleBreakdown => 'Fahrzeugpanne';

  @override
  String get emergencyReasonDriverNoShow => 'Fahrer nicht erschienen';

  @override
  String get emergencyReasonAccident => 'Unfall';

  @override
  String get emergencyReasonPersonalEmergency => 'Persönlicher Notfall';

  @override
  String get emergencyReasonOther => 'Sonstiges';

  @override
  String get preferredDriverLabel => 'Bevorzugt';

  @override
  String emergencyRideLabel(String id) {
    return 'Fahrt: $id';
  }

  @override
  String emergencyOriginalDriverLabel(String id) {
    return 'Ursprünglicher Fahrer: $id';
  }

  @override
  String emergencyNewDriverLabel(String id) {
    return 'Neuer Fahrer: $id';
  }

  @override
  String get ridePoolsTitle => 'Fahrgemeinschaften';

  @override
  String get createRidePoolDialogTitle => 'Fahrgemeinschaft erstellen';

  @override
  String get poolNameOptionalLabel => 'Pool-Name (optional)';

  @override
  String get poolNameHint => 'z.B. Flughafen-Morgenbus';

  @override
  String get routeDirectionOptionalLabel => 'Routenrichtung (optional)';

  @override
  String get routeDirectionHint => 'z.B. Innenstadt → Flughafen';

  @override
  String get maxPassengersLabel => 'Max. Passagiere:';

  @override
  String get ridePoolCreated => 'Fahrgemeinschaft erstellt';

  @override
  String get noRidePools => 'Keine Fahrgemeinschaften';

  @override
  String get createPoolToCombineRides =>
      'Erstellen Sie einen Pool, um Fahrten zu kombinieren';

  @override
  String errorLoadingPoolDetails(String error) {
    return 'Fehler beim Laden der Pool-Details: $error';
  }

  @override
  String get poolDetailStatusLabel => 'Status';

  @override
  String get poolDetailPassengersLabel => 'Passagiere';

  @override
  String get poolDetailRouteLabel => 'Route';

  @override
  String get poolDetailDriverLabel => 'Fahrer';

  @override
  String get poolMembersLabel => 'Mitglieder:';

  @override
  String get noRidesInPool => 'Noch keine Fahrten in diesem Pool';

  @override
  String get companySettingsTitle => 'Unternehmenseinstellungen';

  @override
  String get navItemCompany => 'Unternehmen';

  @override
  String get navItemUsersRoles => 'Benutzer & Rollen';

  @override
  String get navItemCompliance => 'Compliance';

  @override
  String get navItemBillingDatev => 'Abrechnung & DATEV';

  @override
  String get navItemGeofences => 'Geofences';

  @override
  String get companyProfileSectionTitle => 'Unternehmensprofil';

  @override
  String get companyProfileSubtitle =>
      'Rechtliche Informationen auf Rechnungen und Berichten.';

  @override
  String get complianceSectionTitle => 'Compliance & Sicherheit';

  @override
  String get complianceSubtitle =>
      'Datenschutz, Zugriffsverwaltung und Audit-Kontrollen.';

  @override
  String get billingDatevSectionTitle => 'Abrechnung & DATEV';

  @override
  String get billingDatevSubtitle =>
      'Tarifkonfiguration und DATEV-Exporteinstellungen.';

  @override
  String get tariffSettingsSectionTitle => 'Tarifeinstellungen';

  @override
  String get datevIntegrationSectionTitle => 'DATEV-Integration';

  @override
  String get datevIntegrationSubtitle =>
      'Beraternummer und Mandantennummer werden im EXTF-Buchungsstapel-Header verwendet.';

  @override
  String get legalNameLabel => 'Firmenname (rechtlich)';

  @override
  String get vatIdLabel => 'USt-IdNr.';

  @override
  String get defaultCurrencyLabel => 'Standardwährung';

  @override
  String get timezoneLabel => 'Zeitzone';

  @override
  String get commissionRateLabel => 'Provisionsrate (%)';

  @override
  String get cancellationFeeSettingsLabel => 'Stornierungsgebühr (€)';

  @override
  String get noShowFeeLabel => 'Nichterscheinen-Gebühr (€)';

  @override
  String get basePriceLabel => 'Grundpreis (€)';

  @override
  String get pricePerKmLabel => 'Preis pro km (€)';

  @override
  String get airportSurchargeLabel => 'Flughafenzuschlag (€)';

  @override
  String get nightSurchargeLabel => 'Nachtzuschlag (€)';

  @override
  String get workStartLabel => 'Arbeitsbeginn';

  @override
  String get workEndLabel => 'Arbeitsende';

  @override
  String get settingsSavedSuccess => 'Einstellungen erfolgreich gespeichert';

  @override
  String failedToSaveSettings(String error) {
    return 'Fehler beim Speichern: $error';
  }

  @override
  String get gdprExportTitle => 'DSGVO-Export';

  @override
  String get gdprExportSubtitle => 'Alle persönlichen Daten herunterladen';

  @override
  String get auditLogTitle => 'Audit-Protokoll';

  @override
  String get auditLogSubtitle => 'Systemaktivität überprüfen';

  @override
  String get activeSessionsCardTitle => 'Aktive Sitzungen';

  @override
  String get activeSessionsCardSubtitle => 'Angemeldete Geräte verwalten';

  @override
  String get blacklistCardTitle => 'Sperrliste';

  @override
  String get blacklistCardSubtitle => 'Gesperrte Konten verwalten';

  @override
  String comingSoonLabel(String label) {
    return '$label demnächst verfügbar';
  }

  @override
  String get settingsCompanyProfile => 'Unternehmensprofil';

  @override
  String get generalSettingsSectionTitle => 'Allgemeine Einstellungen';

  @override
  String get gdprScreenTitle => 'Datenschutz & Daten (DSGVO)';

  @override
  String get consentManagementSectionTitle => 'Einwilligungsverwaltung';

  @override
  String get consentDataProcessingLabel => 'Datenverarbeitung';

  @override
  String get consentDataProcessingSubtitle =>
      'Verarbeitung von Fahrt- und Kontodaten zulassen';

  @override
  String get consentMarketingLabel => 'Marketing';

  @override
  String get consentMarketingSubtitle => 'Werbe-E-Mails und Angebote erhalten';

  @override
  String get consentAnalyticsLabel => 'Analyse';

  @override
  String get consentAnalyticsSubtitle =>
      'Helfen Sie uns, die App mit Nutzungsanalysen zu verbessern';

  @override
  String get consentThirdPartySharingLabel => 'Weitergabe an Dritte';

  @override
  String get consentThirdPartySharingSubtitle =>
      'Daten mit Partnerdiensten teilen';

  @override
  String get yourDataSectionTitle => 'Ihre Daten';

  @override
  String get exportMyDataLabel => 'Meine Daten exportieren';

  @override
  String get exportMyDataSubtitle =>
      'Alle gespeicherten persönlichen Daten herunterladen';

  @override
  String get dataDeletionSectionTitle => 'Datenlöschung';

  @override
  String get requestDataDeletionLabel => 'Datenlöschung beantragen';

  @override
  String get requestDataDeletionSubtitle =>
      'Alle Daten und Ihr Konto dauerhaft löschen';

  @override
  String get pendingDeletionSubtitle =>
      'Eine Löschanfrage ist bereits ausstehend';

  @override
  String get pendingChipLabel => 'Ausstehend';

  @override
  String get requestHistoryTitle => 'Anfrageverlauf';

  @override
  String get requestDeletionDialogTitle => 'Datenlöschung beantragen';

  @override
  String get requestDeletionDialogContent =>
      'Dies sendet eine Anfrage zur Löschung aller Ihrer persönlichen Daten. Diese Aktion kann nicht rückgängig gemacht werden. Ihr Konto wird nach Bearbeitung der Anfrage deaktiviert.\n\nMöchten Sie wirklich fortfahren?';

  @override
  String get requestDeletionButton => 'Löschung beantragen';

  @override
  String get dataExportCopied => 'Datenexport in die Zwischenablage kopiert';

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get deletionRequestSubmitted => 'Löschanfrage eingereicht';

  @override
  String failedToLoadGdprData(String consentsCode, String requestsCode) {
    return 'Fehler beim Laden der DSGVO-Daten ($consentsCode/$requestsCode)';
  }

  @override
  String get dataDeletionRequestType => 'Datenlöschung';

  @override
  String get dataExportRequestType => 'Datenexport';

  @override
  String get paymentsTitle => 'Zahlungen';

  @override
  String get unpaidBadgeLabel => 'Unbezahlt';

  @override
  String get allRidesPaidLabel => 'Alle Fahrten sind bezahlt';

  @override
  String get markAsPaidDialogTitle => 'Als bezahlt markieren';

  @override
  String get paymentMethodLabel => 'Zahlungsart:';

  @override
  String get paymentMethodSelectLabel => 'Zahlungsart';

  @override
  String get paymentMethodPayment => 'Zahlung';

  @override
  String get paymentMethodCash => 'Bar';

  @override
  String get paymentMethodCard => 'Kreditkarte';

  @override
  String get paymentMethodInvoice => 'Rechnung';

  @override
  String amountLabel(String amount) {
    return 'Betrag: $amount EUR';
  }

  @override
  String get confirmPaymentButton => 'Zahlung bestätigen';

  @override
  String get paymentRecordedSuccess => 'Zahlung erfasst';

  @override
  String get failedToLoadUnpaidRides => 'Fehler beim Laden unbezahlter Fahrten';

  @override
  String myRideTitle(String dateTime) {
    return 'Meine Fahrt · $dateTime';
  }

  @override
  String rideTitle(String client) {
    return 'Fahrt · $client';
  }

  @override
  String get confirmationSentLabel => 'Bestätigung gesendet';

  @override
  String get cancellationDetailsTitle => 'Stornierungsdetails';

  @override
  String cancellationReasonDetail(String reason) {
    return 'Grund: $reason';
  }

  @override
  String cancelledByLabel(String name) {
    return 'Storniert von: $name';
  }

  @override
  String cancellationFeeDisplay(String fee) {
    return 'Gebühr: €$fee';
  }

  @override
  String get ratingTitle => 'Bewertung';

  @override
  String get notesTitle => 'Notizen';

  @override
  String get openChatButton => 'Chat öffnen';

  @override
  String get rideStatusUpdatedSuccess => 'Fahrtstatus erfolgreich aktualisiert';

  @override
  String failedToUpdateRideStatus(String error) {
    return 'Fehler beim Aktualisieren des Fahrtstatus: $error';
  }

  @override
  String get driverAssignedSuccess => 'Fahrer erfolgreich zugewiesen';

  @override
  String failedToAssignDriver(String error) {
    return 'Fehler bei der Fahrerzuweisung: $error';
  }

  @override
  String get rideCancelledSuccess => 'Fahrt storniert';

  @override
  String get completeRideDialogTitle => 'Fahrt abschließen';

  @override
  String get completeRideDialogContent =>
      'Diese Fahrt als abgeschlossen markieren?';

  @override
  String get createNewRideTitle => 'Neue Fahrt erstellen';

  @override
  String get rideCreatedSuccess => 'Fahrt erfolgreich erstellt!';

  @override
  String get conflictDialogTitle => 'Terminkonflikt';

  @override
  String conflictDialogContent(String message) {
    return '$message\n\nDie Fahrt wurde erstellt und befindet sich im Disponenten-Pool. Trotzdem zuweisen?';
  }

  @override
  String get conflictDialogContentDefault =>
      'Sie haben bereits eine Fahrt zu dieser Zeit. Die Fahrt wurde erstellt und befindet sich im Disponenten-Pool. Trotzdem zuweisen?';

  @override
  String conflictDialogContentRich(String from, String to, String time) {
    return 'Der Fahrer ist bereits gebucht: $from → $to um $time.\n\nDie Fahrt wurde erstellt und befindet sich im Dispatcher-Pool. Trotzdem zuweisen?';
  }

  @override
  String get keepInPoolButton => 'Im Pool belassen';

  @override
  String get assignAnywayButton => 'Trotzdem zuweisen';

  @override
  String get exportRidesTitle => 'Fahrten exportieren';

  @override
  String get copyCsvButton => 'CSV kopieren';

  @override
  String get dateRangeButton => 'Zeitraum';

  @override
  String get noRidesMatchFilters => 'Keine Fahrten entsprechen den Filtern';

  @override
  String get exportSummaryTotal => 'Gesamt';

  @override
  String get exportSummaryCompleted => 'Abgeschlossen';

  @override
  String get exportSummaryRevenue => 'Umsatz';

  @override
  String csvCopiedSnackbar(int count) {
    return 'CSV-Daten in die Zwischenablage kopiert ($count Fahrten)';
  }

  @override
  String get okButton => 'OK';

  @override
  String get flightsMunichAirportTitle => 'Flüge · Flughafen München';

  @override
  String get autoSyncedLabel => 'automatisch synchronisiert';

  @override
  String get arrivalsTabLabel => 'Ankünfte';

  @override
  String get arrivalsBoardTitle => 'Ankünfte · Flughafen München';

  @override
  String get departuresTabLabel => 'Abflüge';

  @override
  String get noArrivalsFound => 'Keine Ankünfte gefunden';

  @override
  String get noDeparturesFound => 'Keine Abflüge gefunden';

  @override
  String get flightDetailsTitle => 'Flugdetails';

  @override
  String get gateNotPublished => 'Gate noch nicht veröffentlicht';

  @override
  String get trackFlightLive => 'Live auf Flightradar24 verfolgen';

  @override
  String get couldNotOpenFlightTracker =>
      'Flugverfolgung konnte nicht geöffnet werden';

  @override
  String errorLoadingFlights(String error) {
    return 'Fehler beim Laden der Flüge: $error';
  }

  @override
  String get flightColumnFlight => 'Flug';

  @override
  String get flightColumnOriginDest => 'Herkunft / Ziel';

  @override
  String get flightColumnSched => 'Plan';

  @override
  String get flightColumnStatus => 'Status';

  @override
  String get flightColumnLinkedRide => 'Verknüpfte Fahrt';

  @override
  String get flightStatusOnTime => 'Pünktlich';

  @override
  String get flightStatusDelayed => 'Verspätet';

  @override
  String get flightStatusBoarding => 'Boarding';

  @override
  String get flightStatusCancelled => 'Gestrichen';

  @override
  String get flightStatusUnknown => 'Unbekannt';

  @override
  String get flightStatusScheduled => 'Planmäßig';

  @override
  String get flightStatusDeparted => 'Gestartet';

  @override
  String get flightStatusEnRoute => 'Im Flug';

  @override
  String get flightStatusLanded => 'Gelandet';

  @override
  String get flightStatusDiverted => 'Umgeleitet';

  @override
  String get flightInformation => 'Fluginformationen';

  @override
  String get flightNumber => 'Flugnummer';

  @override
  String get arrivalTime => 'Ankunftszeit';

  @override
  String get departureTime => 'Abflugzeit';

  @override
  String get flightNotLinked => '— nicht verknüpft';

  @override
  String get whoCanSeeWhomTitle => 'Wer sieht wen';

  @override
  String get visibleToAllDispatchers => 'Für alle Disponenten sichtbar';

  @override
  String get scheduleHiddenFromOthers => 'Zeitplan für andere verborgen';

  @override
  String get noDriversInCompany => 'Keine Fahrer in Ihrem Unternehmen.';

  @override
  String failedToUpdateVisibilityError(String error) {
    return 'Fehler beim Aktualisieren der Sichtbarkeit: $error';
  }

  @override
  String get auditLogScreenTitle => 'Audit-Protokoll';

  @override
  String get searchByEntityIdHint => 'Nach Entitäts-ID suchen...';

  @override
  String get noAuditEntriesFound => 'Keine Audit-Einträge gefunden';

  @override
  String onlineOnRideLabel(String dateTime) {
    return 'Online · Fahrt um $dateTime';
  }

  @override
  String get startConversationSubtitle =>
      'Beginnen Sie die Unterhaltung mit dem Fahrer';

  @override
  String failedToSendMessage(String error) {
    return 'Fehler beim Senden: $error';
  }

  @override
  String get totalRidesStatLabel => 'Fahrten gesamt';

  @override
  String get onTimeStatLabel => 'Pünktlich';

  @override
  String get completionRateStatLabel => 'Abschlussquote';

  @override
  String get avgSlackStatLabel => 'Ø Puffer';

  @override
  String get gmvStatLabel => 'GMV';

  @override
  String get ridesByTenantTitle => 'Fahrten nach Mandant';

  @override
  String get rideStatusBreakdownTitle => 'Fahrtstatus-Übersicht';

  @override
  String get platformActiveSessionsLabel => 'Aktive Plattformsitzungen';

  @override
  String get clientPaymentTitle => 'Zahlung';

  @override
  String get paymentMethodsSectionLabel => 'ZAHLUNGSARTEN';

  @override
  String get corporateInvoiceLabel => 'Firmenrechnung';

  @override
  String get addPaymentMethodButton => 'Zahlungsart hinzufügen';

  @override
  String get shareRideLink => 'Tracking-Link teilen';

  @override
  String get trackingLinkCopied =>
      'Tracking-Link in die Zwischenablage kopiert';

  @override
  String get bookWithoutClient => 'Ohne Kunden (aus Chat)';

  @override
  String get fromChatRide => 'Aus Chat';

  @override
  String get linkClient => 'Kunden ergänzen';

  @override
  String get calendarSharingTitle => 'Kalenderfreigabe';

  @override
  String get calendarSharingMenuItem => 'Kalenderfreigabe';

  @override
  String get shareInvitesSection => 'Meine Einladungscodes';

  @override
  String get shareCreateInvite => 'Einladungscode erstellen';

  @override
  String get shareInviteExpiry1Day => '1 Tag';

  @override
  String get shareInviteExpiry7Days => '7 Tage';

  @override
  String get shareInviteExpiry30Days => '30 Tage';

  @override
  String get shareInviteCreatedTitle => 'Einladungscode erstellt';

  @override
  String get shareInviteCreatedHint =>
      'Senden Sie diesen Code an einen Fahrer oder Disponenten eines anderen Unternehmens. Er wird in deren App unter Kalenderfreigabe eingegeben.';

  @override
  String get shareCopyCode => 'Code kopieren';

  @override
  String get shareCodeCopied => 'Code in die Zwischenablage kopiert';

  @override
  String get shareRevoke => 'Widerrufen';

  @override
  String get shareGrantedSection => 'Wer sieht meinen Kalender';

  @override
  String get shareSharedWithMeSection => 'Für mich freigegeben';

  @override
  String get shareEnterCode => 'Code eingeben';

  @override
  String get shareRedeemTitle => 'Freigegebenen Kalender verbinden';

  @override
  String get shareRedeemHint => 'Einladungscode oder Link einfügen';

  @override
  String get shareRedeemConnect => 'Verbinden';

  @override
  String shareRedeemSuccess(String name) {
    return 'Verbunden mit $name';
  }

  @override
  String get shareUnlink => 'Trennen';

  @override
  String get shareNoInvites => 'Keine aktiven Einladungscodes';

  @override
  String get shareNoGrants => 'Sie haben Ihren Kalender mit niemandem geteilt';

  @override
  String get shareNoSharedWithMe => 'Keine Kalender für Sie freigegeben';

  @override
  String shareValidUntil(String date) {
    return 'Gültig bis $date';
  }

  @override
  String shareSince(String date) {
    return 'Seit $date';
  }

  @override
  String shareActionFailed(String error) {
    return 'Aktion fehlgeschlagen: $error';
  }

  @override
  String get sharedCalendarAvailable => 'Verfügbar';

  @override
  String get sharedCalendarBusy => 'Belegt';

  @override
  String get sharedCalendarShift => 'Schicht';

  @override
  String get sharedCalendarEmptyDay => 'Keine Schichten oder belegten Zeiten';

  @override
  String get sharedCalendarEmptyWeek =>
      'Keine Schichten oder belegten Zeiten in dieser Woche';

  @override
  String sharedCalendarTimesHint(String company) {
    return 'Schichtzeiten wie von $company angegeben';
  }

  @override
  String get sharedWithMeGroupLabel => 'Für mich freigegeben';

  @override
  String get myCompanyGroupLabel => 'Mein Unternehmen';

  @override
  String get addShiftTooltip => 'Schicht hinzufügen';

  @override
  String get addShiftTitle => 'Neue Schicht';

  @override
  String get shiftDateLabel => 'Datum';

  @override
  String get shiftStartLabel => 'Beginn';

  @override
  String get shiftEndLabel => 'Ende';

  @override
  String get shiftRepeatUntilLabel => 'Täglich wiederholen bis (optional)';

  @override
  String get shiftNoteLabel => 'Notiz (optional)';

  @override
  String get shiftCreateButton => 'Erstellen';

  @override
  String shiftsCreatedSnack(int count) {
    return 'Schichten erstellt: $count';
  }

  @override
  String get shiftOverlapSnack =>
      'Die gewählte Zeit überschneidet sich mit einer bestehenden Schicht. Mehrere Schichten pro Tag sind erlaubt — wählen Sie eine überschneidungsfreie Zeit.';

  @override
  String get shiftTimeOrderError => 'Beginn muss vor dem Ende liegen';

  @override
  String get shiftCancelTitle => 'Diese Schicht stornieren?';

  @override
  String get shiftCancelButton => 'Schicht stornieren';

  @override
  String get shiftCancelledSnack => 'Schicht storniert';

  @override
  String get shiftsStripLabel => 'Schichten';

  @override
  String get noShiftsForDay => 'Keine Schichten';
}
