/// Safe accessors for decoding JSON from the API.
///
/// The models used to call `DateTime.parse(json['x'])` and `(json['x'] as num)`
/// directly. A single null or malformed field then threw and took down the whole
/// `fromJson` — e.g. one bad `pickupDateTime` made an entire ride list fail to
/// load. These helpers make that failure mode explicit and contained:
///
/// * `optional*` returns null for a missing/null/malformed value, so a single bad
///   optional field never breaks the rest of the object.
/// * `required*` throws a [FormatException] that names the offending field, so a
///   genuine contract violation surfaces with a useful message instead of an
///   opaque `type 'Null' is not a subtype of String` deep in a parser.
///
/// They deliberately do NOT silently substitute defaults (e.g. `DateTime.now()`)
/// for required fields — that hides backend bugs and writes wrong data into the UI.
class JsonParse {
  JsonParse._();

  /// Parses a required ISO-8601 datetime. Throws [FormatException] naming [key]
  /// when the value is missing or unparseable.
  static DateTime requiredDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key];
    final parsed = _tryDateTime(raw);
    if (parsed == null) {
      throw FormatException(
        'Expected an ISO-8601 datetime for "$key", got: ${raw ?? 'null'}',
      );
    }
    return parsed;
  }

  /// Parses an optional ISO-8601 datetime. Returns null when missing or
  /// unparseable instead of throwing.
  static DateTime? optionalDateTime(Map<String, dynamic> json, String key) =>
      _tryDateTime(json[key]);

  /// Parses a required number to double. Throws [FormatException] naming [key]
  /// when the value is missing or not a number.
  static double requiredDouble(Map<String, dynamic> json, String key) {
    final parsed = _tryDouble(json[key]);
    if (parsed == null) {
      throw FormatException(
        'Expected a number for "$key", got: ${json[key] ?? 'null'}',
      );
    }
    return parsed;
  }

  /// Parses an optional number to double, falling back to [fallback] (default 0)
  /// when missing or not a number.
  static double optionalDouble(
    Map<String, dynamic> json,
    String key, {
    double fallback = 0,
  }) => _tryDouble(json[key]) ?? fallback;

  /// Reads a required string. Throws [FormatException] naming [key] when missing
  /// or not a string.
  static String requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException(
      'Expected a string for "$key", got: ${value ?? 'null'}',
    );
  }

  /// Reads an optional string, returning null when missing or not a string.
  static String? optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String ? value : null;
  }

  static DateTime? _tryDateTime(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static double? _tryDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }
}
