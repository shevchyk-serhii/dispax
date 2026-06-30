import 'package:flutter/services.dart';

/// Input formatter that forces every keystroke to upper case, keeping the cursor
/// where it was. Flight numbers are always upper case (LH429, BA1, 4Y1410), so
/// the field transforms as the user types instead of relying on a later trim.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    // Only rebuild the value when the case actually changed, so the selection
    // (cursor) the framework computed for newValue is preserved verbatim.
    if (upper == newValue.text) return newValue;
    return newValue.copyWith(text: upper);
  }
}

/// Pure flight-number helpers, kept widget-free so they unit-test in isolation and
/// can be reused by any field/form. Mirrors the backend `MucFlightParser.normalizeFlightNumber`
/// (strip whitespace, upper-case) so the client and server agree on the canonical form.
class FlightNumber {
  FlightNumber._();

  // Airline code + 1-4 digit number + optional trailing operational-suffix letter
  // (rare, e.g. LH429A), applied to the already-normalized (no-space, upper) form.
  // The code is spelled out as explicit alternatives instead of `[A-Z0-9]{2,3}` so a
  // generic alphanumeric run can't swallow the flight digits (which let "LH12345"
  // through): IATA is two chars with at most one digit (LH, U2, 4Y), ICAO is three
  // letters (DLH, BAW).
  static final RegExp _pattern = RegExp(
    r'^([A-Z]{2}|[A-Z]\d|\d[A-Z]|[A-Z]{3})\d{1,4}[A-Z]?$',
  );

  /// Canonical form: drop all whitespace, upper-case. Matches the backend.
  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// True when [raw] is a plausible IATA/ICAO flight number. An EMPTY value is
  /// considered valid here (the number is optional on an airport transfer — the
  /// caller decides whether emptiness is allowed separately).
  static bool isValid(String raw) {
    final n = normalize(raw);
    if (n.isEmpty) return true;
    return _pattern.hasMatch(n);
  }
}
