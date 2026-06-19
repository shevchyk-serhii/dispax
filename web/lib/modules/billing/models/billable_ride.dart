import '../../core/json_parse.dart';

/// A completed, unbilled ride eligible to be added to an invoice. Mirrors the
/// backend BillableRideDto. Ids arrive as flat strings.
class BillableRide {
  final String rideId;
  final String clientId;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime pickupDatetime;
  final double price;

  const BillableRide({
    required this.rideId,
    required this.clientId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupDatetime,
    required this.price,
  });

  factory BillableRide.fromJson(Map<String, dynamic> json) => BillableRide(
    rideId: JsonParse.requiredString(json, 'rideId'),
    clientId: JsonParse.requiredString(json, 'clientId'),
    pickupAddress: JsonParse.requiredString(json, 'pickupAddress'),
    dropoffAddress: JsonParse.requiredString(json, 'dropoffAddress'),
    pickupDatetime: JsonParse.requiredDateTime(json, 'pickupDatetime'),
    price: JsonParse.requiredDouble(json, 'price'),
  );
}
