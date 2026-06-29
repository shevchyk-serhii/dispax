import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../models/ride.dart';

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
    if (s.contains('en_route') ||
        s.contains('en route') ||
        s.contains('unterwegs')) {
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

  /// Base arrival-time label for an airport ride, distinguishing forecast from fact:
  /// once the flight has landed the time IS the actual landing time → "Gelandet um HH:mm";
  /// while still airborne it is only an estimate/schedule → "Landung um HH:mm".
  /// The delay suffix is added by the caller (it is styled differently per card).
  /// Assumes [ride.flightTime] is non-null (callers gate on it).
  String airportArrivalText(Ride ride) {
    final time = DateFormat.Hm().format(ride.flightTime!);
    return ride.flightHasLanded
        ? airportLandedAt(time)
        : airportLandingAt(time);
  }
}
