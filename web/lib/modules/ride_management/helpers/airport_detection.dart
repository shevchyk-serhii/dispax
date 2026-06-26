import '../models/ride.dart';

/// Address tokens that mark a pickup/drop-off as an airport, independent of the
/// explicit `isAirportTransfer` flag a creator may set when booking a flight
/// transfer. Lower-cased; matched as substrings against the ride addresses.
///
/// The flag (`Ride.isAirportTransfer`) is only set when the booker toggles
/// "Airport transfer" at creation time (it drives flight tracking, surcharges
/// and airport checkpoints). A ride simply going to/from the airport — typed as
/// a plain address — carries no flag, so the dispatcher's "Airport" chip would
/// miss it. This token list lets the chip recognise those rides by address too.
const List<String> _airportAddressTokens = [
  'flughafen',
  'airport',
  'terminal 1',
  'terminal 2',
  // Munich Airport (MUC) — the MVP target city.
  'muc',
  '85356', // Flughafen München postal code
];

/// Whether [address] looks like an airport location by its text.
bool addressLooksLikeAirport(String address) {
  final lower = address.toLowerCase();
  return _airportAddressTokens.any(lower.contains);
}

/// Whether [ride] should be treated as an airport ride for filtering/labelling.
///
/// True when the ride carries the explicit airport-transfer flag OR either of
/// its endpoints reads as an airport address. This is the predicate the
/// dispatcher's "Airport" filter uses, so a ride to/from the airport surfaces
/// even when the booker didn't toggle the flag.
bool isAirportRide(Ride ride) =>
    ride.isAirportTransfer ||
    addressLooksLikeAirport(ride.from.address) ||
    addressLooksLikeAirport(ride.to.address);
