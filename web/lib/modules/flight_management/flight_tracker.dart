import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Deep-links a flight number to its Flightradar24 page, where — once the aircraft
/// is airborne — the dispatcher/driver can see its real-time position on the map.
///
/// Flightradar24's canonical per-flight URL is `/data/flights/<number>` with the
/// flight number lower-cased and stripped of spaces (e.g. "LH 429" → "lh429").
class FlightTracker {
  FlightTracker._();

  /// The Flightradar24 page URL for [flightNumber], or null when the number is
  /// blank (nothing to link to). Pure + null-returning so it is unit-testable.
  static Uri? flightradarUrl(String? flightNumber) {
    final cleaned = (flightNumber ?? '')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
    if (cleaned.isEmpty) return null;
    return Uri.parse('https://www.flightradar24.com/data/flights/$cleaned');
  }

  /// Opens the Flightradar24 page for [flightNumber] in an external browser.
  /// Returns false when there is nothing to open or the launch failed (the
  /// caller can surface a message). Never throws.
  static Future<bool> open(String? flightNumber) async {
    final uri = flightradarUrl(flightNumber);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ flight tracker launch failed: $e');
      return false;
    }
  }
}
