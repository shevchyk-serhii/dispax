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
    rideId: json['rideId'] as String,
    clientId: json['clientId'] as String,
    pickupAddress: json['pickupAddress'] as String,
    dropoffAddress: json['dropoffAddress'] as String,
    pickupDatetime: DateTime.parse(json['pickupDatetime'] as String),
    price: (json['price'] as num).toDouble(),
  );
}
