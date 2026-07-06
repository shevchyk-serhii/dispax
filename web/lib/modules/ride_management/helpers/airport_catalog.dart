import '../../core/models/location.dart';

/// A known airport that can be auto-filled into the ride form when the operator
/// enables the airport-transfer toggle.
///
/// The backend airport reference (`airports` table) is a SuperAdmin-only,
/// address-less catalog (code/name/coordinates), so the human-readable address
/// string lives here — mirroring how MUC is already hardcoded across the app
/// (see `muc_checkpoints.dart`, `create_ride_form_helper.dart` gate/terminal
/// lists). When a second airport is added to [all], the form can expose a
/// picker; today there is exactly one, so it is auto-selected.
class CatalogAirport {
  /// IATA code, e.g. "MUC".
  final String code;

  /// Canonical human-readable address written into the ride's `from`/`to`.
  final String address;

  /// Short label for the read-only chip shown in the form.
  final String label;

  final double latitude;
  final double longitude;

  const CatalogAirport({
    required this.code,
    required this.address,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  /// A [Location] carrying both the canonical address and coordinates, so
  /// downstream ETA/distance computations get real coordinates and not just a
  /// text string.
  Location toLocation() =>
      Location(address: address, latitude: latitude, longitude: longitude);
}

/// Munich Airport (MUC). Coordinates match the MUC values used elsewhere
/// (superadmin airport config and `MucCheckpoints`): 48.3537 / 11.786.
const CatalogAirport _muc = CatalogAirport(
  code: 'MUC',
  address: 'Flughafen München, Nordallee 25, 85356 München',
  label: 'Flughafen München (MUC)',
  latitude: 48.3537,
  longitude: 11.786,
);

/// The known airports. MVP targets Munich, so this holds a single entry.
const List<CatalogAirport> _airports = [_muc];

/// All airports available for auto-fill.
const List<CatalogAirport> allAirports = _airports;

/// The airport to auto-fill when the transfer toggle is enabled. With a single
/// airport this is always MUC; a future multi-airport UI would replace this
/// with an operator-selected value.
const CatalogAirport defaultAirport = _muc;

/// The catalog airport whose canonical address equals [address] (trimmed), or
/// null when [address] is not an auto-filled airport address.
CatalogAirport? catalogAirportForAddress(String address) {
  final trimmed = address.trim();
  for (final airport in _airports) {
    if (airport.address == trimmed) return airport;
  }
  return null;
}

/// Whether [address] is one of the catalog airports' canonical address (i.e. an
/// address the form auto-filled). Used to decide whether an airport field may be
/// safely re-filled/cleared without clobbering an operator-typed address.
bool isCatalogAirportAddress(String address) =>
    catalogAirportForAddress(address) != null;

/// Builds a [Location] for [address], attaching the airport's coordinates when
/// [address] is a known catalog airport so downstream ETA/distance uses real
/// coordinates instead of only a text string. Non-airport addresses yield a
/// coordinate-less [Location].
Location locationForAddress(String address) {
  final airport = catalogAirportForAddress(address);
  return airport?.toLocation() ?? Location(address: address.trim());
}
