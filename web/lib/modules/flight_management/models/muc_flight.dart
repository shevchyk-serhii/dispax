import '../../core/json_parse.dart';

/// A single flight row from the MUC arrivals board (GET /api/flights/arrivals).
/// Times arrive as ISO-8601 UTC strings and are parsed to local DateTime for display.
class MucFlight {
  final String flightNumber;

  /// Backend wire status ("landed", "delayed", "scheduled", "unknown", …).
  /// Localize for display via AppLocalizations.localizedFlightStatus.
  final String status;
  final DateTime? scheduledTime;
  final DateTime? estimatedTime;
  final String? terminal;
  final String? gate;
  final String? airline;

  /// IATA code of the origin airport (where the flight comes from).
  final String? origin;

  const MucFlight({
    required this.flightNumber,
    required this.status,
    this.scheduledTime,
    this.estimatedTime,
    this.terminal,
    this.gate,
    this.airline,
    this.origin,
  });

  /// Delay in minutes (estimated − scheduled) when both are known and the flight is late.
  int? get delayMinutes {
    final s = scheduledTime;
    final e = estimatedTime;
    if (s == null || e == null) return null;
    return e.difference(s).inMinutes;
  }

  bool get isDelayed {
    final d = delayMinutes;
    if (d != null && d > 0) return true;
    return status.toLowerCase() == 'delayed';
  }

  factory MucFlight.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? v) =>
        v == null ? null : DateTime.tryParse(v)?.toLocal();
    return MucFlight(
      flightNumber: JsonParse.requiredString(json, 'flightNumber'),
      status: (json['status'] as String?) ?? 'unknown',
      scheduledTime: parse(json['scheduledTime'] as String?),
      estimatedTime: parse(json['estimatedTime'] as String?),
      terminal: json['terminal'] as String?,
      gate: json['gate'] as String?,
      airline: json['airline'] as String?,
      origin: json['origin'] as String?,
    );
  }
}
