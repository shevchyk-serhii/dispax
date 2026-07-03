/// Parses a user-entered monetary/decimal amount, accepting both the German
/// decimal comma ("12,50", "1.234,56") and the dot ("12.50", "1,234.56").
///
/// `double.tryParse` is locale-invariant (US format only), so on a German
/// keyboard "12,50" either fails or — behind a `?? 0` fallback — is silently
/// zeroed. Returns null for input that is not a number, so callers can
/// distinguish garbage from a real 0 and reject it instead of storing 0.
double? parseAmount(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      // German style: dots are thousands separators, comma is the decimal.
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // US style: commas are thousands separators.
      s = s.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    if (s.indexOf(',') == lastComma) {
      // A single comma is a decimal separator ("12,50").
      s = s.replaceAll(',', '.');
    } else {
      // Multiple commas can only be thousands separators ("1,234,567").
      s = s.replaceAll(',', '');
    }
  } else if (lastDot >= 0 && s.indexOf('.') != lastDot) {
    // Multiple dots can only be German thousands separators ("1.234.567").
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}
