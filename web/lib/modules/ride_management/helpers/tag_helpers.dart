import '../models/ride.dart';

/// Client-side tag helpers mirroring the backend `TagNormalizer` so the create
/// form, edit dialog, and dispatcher filter all agree on what a tag is.

/// Trims and collapses internal whitespace in a single tag. Returns '' for a
/// blank/whitespace-only input.
String normalizeTag(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Whether [ride] carries [tag] (case-insensitive), used by the dispatcher's
/// tag filter. Safe even though the backend normalizes, since edits round-trip.
bool rideHasTag(Ride ride, String tag) {
  final needle = tag.toLowerCase();
  return ride.tags.any((t) => t.toLowerCase() == needle);
}

/// Distinct tags across [rides], de-duplicated case-insensitively (first-seen
/// casing wins) and sorted, for suggestion chips and the filter row. Source is
/// the already-loaded, company-scoped rides — no extra backend call needed.
List<String> distinctTagsFromRides(Iterable<Ride> rides) {
  final seen = <String, String>{};
  for (final ride in rides) {
    for (final tag in ride.tags) {
      final key = tag.toLowerCase();
      seen.putIfAbsent(key, () => tag);
    }
  }
  final result = seen.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}
