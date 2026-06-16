/// Hardcoded MUC airport checkpoint coordinates for MVP.
/// T1 coordinates are used as the default chain.
/// The server knows the actual terminal from rides.flight_terminal.
class MucCheckpoint {
  final String
  key; // matches backend: "landed" | "arrivals_hall" | "terminal_exit"
  final String labelKey; // l10n key
  final double lat;
  final double lon;

  const MucCheckpoint({
    required this.key,
    required this.labelKey,
    required this.lat,
    required this.lon,
  });
}

class MucCheckpoints {
  static const List<MucCheckpoint> chain = [
    MucCheckpoint(
      key: 'landed',
      labelKey: 'checkpointLanded',
      lat: 48.3537,
      lon: 11.7860,
    ),
    MucCheckpoint(
      key: 'arrivals_hall',
      labelKey: 'checkpointArrivalsHall',
      lat: 48.3526,
      lon: 11.7798,
    ),
    MucCheckpoint(
      key: 'terminal_exit',
      labelKey: 'checkpointTerminalExit',
      lat: 48.3515,
      lon: 11.7793,
    ),
  ];

  /// Returns the ordinal of the checkpoint key (0=landed, 1=arrivals_hall, 2=terminal_exit, -1=null).
  static int ordinal(String? key) {
    if (key == null) return -1;
    return chain.indexWhere((c) => c.key == key);
  }
}
