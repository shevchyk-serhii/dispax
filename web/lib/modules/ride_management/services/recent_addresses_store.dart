import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/client_address.dart';

/// Local, device-only cache of recently/frequently entered ride addresses.
///
/// This is the client-side MRU cache half of the "typeahead like prod" pattern:
/// it lets the create-ride form show instant, offline suggestions (recent +
/// frequent addresses) before any Mapbox request, and surface them even for a
/// short query where the live suggester stays quiet (`< 3` chars).
///
/// Storage is a single JSON array under [prefsKey] in SharedPreferences. Each
/// record ≈ a few hundred bytes, capped at [maxEntries] — tens of KB total.
///
/// Records are exposed as [ClientAddress] to reuse the existing suggestion
/// widget (which already renders the `Icons.history` + `×useCount` affordance).
/// Purely-local records carry empty `id`/`clientId` and a synthetic timestamp.
class RecentAddressesStore {
  static const String prefsKey = 'recent_ride_addresses';

  /// Cap on stored records. Eviction drops the least valuable entry first
  /// (lowest useCount, then oldest lastUsedAt) — see [applyRecord].
  static const int maxEntries = 50;

  /// Synthetic timestamp for the [ClientAddress] fields the model requires but
  /// that carry no meaning for a local suggestion.
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  const RecentAddressesStore();

  /// Loads the cached addresses, most valuable first (see [rank]). Returns an
  /// empty list (never throws) when nothing is stored or the payload is corrupt.
  Future<List<ClientAddress>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return decode(prefs.getString(prefsKey))
        .map(
          (r) => ClientAddress(
            id: '',
            clientId: '',
            label: '',
            address: r.address,
            latitude: r.latitude,
            longitude: r.longitude,
            useCount: r.useCount,
            createdAt: _epoch,
            updatedAt: _epoch,
          ),
        )
        .toList();
  }

  /// Records one use of [address]: increments its useCount (or inserts it),
  /// refreshes coordinates when [latitude]/[longitude] are provided, and stamps
  /// [usedAtMillis] (defaults to now) as its recency. Blank addresses are
  /// ignored. Persists the capped, re-ranked list.
  Future<void> record(
    String address, {
    double? latitude,
    double? longitude,
    int? usedAtMillis,
  }) => recordAll([address], usedAtMillis: usedAtMillis);

  /// Records a use of each address in [addresses] in a single read-modify-write.
  /// Doing both endpoints (from/to) as one load+store avoids the last-writer-
  /// wins race two concurrent [record] calls would have on the shared key.
  /// Blank addresses are skipped; if none remain nothing is written.
  Future<void> recordAll(List<String> addresses, {int? usedAtMillis}) async {
    final stamp = usedAtMillis ?? DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    var records = decode(prefs.getString(prefsKey));
    var changed = false;
    for (final address in addresses) {
      if (address.trim().isEmpty) continue;
      records = applyRecord(records, address, usedAtMillis: stamp);
      changed = true;
    }
    if (!changed) return;
    await prefs.setString(prefsKey, encode(records));
  }

  // --- Pure helpers (no I/O), unit-testable without SharedPreferences ---

  /// Applies one use of [address] to [current], returning a new capped,
  /// re-ranked list. If the (case-insensitive) address already exists its
  /// useCount is bumped and coordinates/recency refreshed; otherwise it is
  /// inserted with useCount 1. When the cap is exceeded the least valuable
  /// entry (see [rank]) is evicted.
  static List<RecentAddress> applyRecord(
    List<RecentAddress> current,
    String address, {
    double? latitude,
    double? longitude,
    required int usedAtMillis,
  }) {
    final key = address.trim().toLowerCase();
    final out = <RecentAddress>[];
    var found = false;
    for (final r in current) {
      if (r.address.trim().toLowerCase() == key) {
        found = true;
        out.add(
          RecentAddress(
            address: r.address,
            latitude: latitude ?? r.latitude,
            longitude: longitude ?? r.longitude,
            useCount: r.useCount + 1,
            usedAtMillis: usedAtMillis,
          ),
        );
      } else {
        out.add(r);
      }
    }
    if (!found) {
      out.add(
        RecentAddress(
          address: address.trim(),
          latitude: latitude,
          longitude: longitude,
          useCount: 1,
          usedAtMillis: usedAtMillis,
        ),
      );
    }
    out.sort(rank);
    if (out.length > maxEntries) {
      return out.sublist(0, maxEntries);
    }
    return out;
  }

  /// Ordering: highest useCount first, then most recent. Puts the most valuable
  /// suggestions at the top and the eviction candidate at the tail.
  static int rank(RecentAddress a, RecentAddress b) {
    final byCount = b.useCount.compareTo(a.useCount);
    if (byCount != 0) return byCount;
    return b.usedAtMillis.compareTo(a.usedAtMillis);
  }

  /// Parses the stored JSON array, ranked. Returns `[]` (never throws) for a
  /// null/blank/corrupt payload.
  static List<RecentAddress> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      final out = <RecentAddress>[];
      for (final item in data) {
        final parsed = RecentAddress.tryFromJson(item);
        if (parsed != null) out.add(parsed);
      }
      out.sort(rank);
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Serializes [records] to the stored JSON array form.
  static String encode(List<RecentAddress> records) =>
      jsonEncode(records.map((r) => r.toJson()).toList());
}

/// One persisted recent-address record. Distinct from [ClientAddress] so the
/// on-disk shape stays minimal (no id/label/aliases) and carries the recency
/// (`usedAtMillis`) used for eviction.
class RecentAddress {
  final String address;
  final double? latitude;
  final double? longitude;
  final int useCount;
  final int usedAtMillis;

  const RecentAddress({
    required this.address,
    this.latitude,
    this.longitude,
    required this.useCount,
    required this.usedAtMillis,
  });

  Map<String, dynamic> toJson() => {
    'address': address,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    'useCount': useCount,
    'usedAtMillis': usedAtMillis,
  };

  /// Parses one record, or `null` when [raw] is not a map with a non-blank
  /// `address`. Missing numeric fields default sensibly (useCount 1, epoch).
  static RecentAddress? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final address = raw['address'];
    if (address is! String || address.trim().isEmpty) return null;
    return RecentAddress(
      address: address,
      latitude: (raw['latitude'] as num?)?.toDouble(),
      longitude: (raw['longitude'] as num?)?.toDouble(),
      useCount: (raw['useCount'] as num?)?.toInt() ?? 1,
      usedAtMillis: (raw['usedAtMillis'] as num?)?.toInt() ?? 0,
    );
  }
}
