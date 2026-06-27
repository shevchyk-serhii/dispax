import '../../../l10n/app_localizations.dart';

/// Maps a backend flight-status wire string (e.g. "scheduled", "delayed", "landed",
/// "unknown") to a localized label. Single source of truth so every card/dialog shows
/// the status the same way, in the user's language. Unknown/unmapped → the neutral
/// "Unknown" label (never the raw wire string).
extension RideFlightStatusL10n on AppLocalizations {
  String localizedFlightStatus(String? status) {
    if (status == null) {
      return '';
    }
    final s = status.toLowerCase().trim();
    if (s.contains('on time')) {
      return flightStatusOnTime;
    }
    if (s.contains('scheduled') || s.contains('planmäßig')) {
      return flightStatusScheduled;
    }
    if (s.contains('boarding') || s.contains('einstieg')) {
      return flightStatusBoarding;
    }
    if (s.contains('en_route') || s.contains('en route') || s.contains('unterwegs')) {
      return flightStatusEnRoute;
    }
    if (s.contains('departed') || s.contains('gestartet')) {
      return flightStatusDeparted;
    }
    if (s.contains('landed') || s.contains('gelandet')) {
      return flightStatusLanded;
    }
    if (s.contains('delay') || s.contains('late') || s.contains('verspät')) {
      return flightStatusDelayed;
    }
    if (s.contains('cancel') || s.contains('gestrichen')) {
      return flightStatusCancelled;
    }
    if (s.contains('divert') || s.contains('umgeleitet')) {
      return flightStatusDiverted;
    }
    return flightStatusUnknown;
  }
}
