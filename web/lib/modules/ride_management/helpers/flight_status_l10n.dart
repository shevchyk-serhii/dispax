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

  /// The gate value to show for a ride, localizing the remote-stand sentinel: a "REMOTE"
  /// gate becomes the "bus gate" label (no real code), any other gate is returned as-is.
  /// Returns null when there is no gate at all.
  String? localizedGate(Ride ride) {
    if (ride.gate == null) return null;
    return ride.isRemoteGate ? gateRemote : ride.gate;
  }

  /// Localized flight line (number + gate/terminal), mirroring [Ride.fullFlightInfo] but
  /// rendering a remote stand as the localized "bus gate" label instead of the raw word.
  String fullFlightInfoLocalized(Ride ride) {
    if (!ride.isAirportTransfer || ride.flightNumber == null) return '';

    final parts = <String>['${ride.flightIcon} ${ride.flightNumber}'];
    final gate = localizedGate(ride);

    if (gate != null && ride.terminal != null) {
      // For a real gate keep the "Gate G35" prefix; the remote label is already self-describing.
      final gateText = ride.isRemoteGate ? gate : '$gateLabel $gate';
      parts.add('$gateText ($terminalLabel ${ride.terminal})');
    } else if (gate != null) {
      parts.add(ride.isRemoteGate ? gate : '$gateLabel $gate');
    } else if (ride.terminal != null) {
      parts.add('$terminalLabel ${ride.terminal}');
    }

    return parts.join(' • ');
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
