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
}
